import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'config/app_config.dart';
import 'models/app_user.dart';
import 'repositories/app_data_repository.dart';
import 'repositories/auth_repository.dart';
import 'repositories/local_repository.dart';
import 'repositories/supabase_repository.dart';
import 'screens/admin_home_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/recovery_screen.dart';
import 'screens/signup_screen.dart';
import 'services/push_notification_service.dart';
import 'services/resilient_auth_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Android 15/16 enforce edge-to-edge for apps targeting modern SDKs.
  // Keep both system bars transparent and let Flutter SafeAreas protect
  // interactive controls from status/navigation bars and display cutouts.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  // The first Flutter frame must never depend on a network/service startup.
  // If Supabase initialization fails for any reason, start with the local
  // repository instead of terminating before runApp().
  SupabaseClient? client;
  String? startupError;
  if (AppConfig.serverEnabled) {
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        publishableKey: AppConfig.supabaseKey,
        authOptions: FlutterAuthClientOptions(
          localStorage: ResilientAuthStorage(
            persistSessionKey: 'sb-' +
                Uri.parse(AppConfig.supabaseUrl).host.split('.').first +
                '-auth-token',
          ),
          // This app uses server-side SMS verification, not OAuth callbacks.
          // Do not initialize the native app-links plugin on first frame.
          detectSessionInUri: false,
        ),
      );
      client = Supabase.instance.client;
    } catch (error, stackTrace) {
      final detail = error is PlatformException
          ? error.code + ': ' + (error.message ?? '플랫폼 플러그인 오류')
          : error.runtimeType.toString();
      startupError = '인증 서버 초기화에 실패했습니다. (' +
          (detail.length > 180 ? detail.substring(0, 180) : detail) + ')';
      debugPrint('Supabase startup failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  runApp(CampingCarRoadmapApp(client: client, startupError: startupError));

  // Start optional push services only after Flutter has rendered the app.
  // A native Firebase/FCM failure must never block the first app frame.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    Future<void>(() async {
      try {
        await PushNotificationService.instance.initialize(client);
      } catch (error, stackTrace) {
        debugPrint('Push startup failed after first frame: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    });
  });
}

class CampingCarRoadmapApp extends StatefulWidget {
  const CampingCarRoadmapApp({super.key, this.client, this.startupError});
  final SupabaseClient? client;
  final String? startupError;
  @override
  State<CampingCarRoadmapApp> createState() => _CampingCarRoadmapAppState();
}

class _CampingCarRoadmapAppState extends State<CampingCarRoadmapApp> {
  final local = LocalRepository();
  late final AuthRepository auth;
  late final AppDataRepository data;
  AppUser? user;
  bool ready = false;
  bool versionChecked = false;
  bool updateRequired = false;
  String updateUrl = 'https://play.google.com/store/apps/details?id=kr.co.campingcarroadmap.app';
  static const int currentVersionCode = 133;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  Map<String,dynamic>? _pendingNotification;
  void _handleNotification(Map<String,dynamic> event){_pendingNotification=event;_openNotification();}
  void _openNotification(){if(!mounted||!ready||user==null||_pendingNotification==null)return;final event=_pendingNotification!;final id='${event['reference_id']??''}';if(id.isEmpty)return;_pendingNotification=null;final kind='${event['kind']??''}'.toLowerCase();final navigator=_navigatorKey.currentState;if(navigator==null){_pendingNotification=event;return;}if(kind.contains('place')||kind.contains('location')){navigator.push(MaterialPageRoute(builder:(_)=>user!.isAdministrator?AdminHomeScreen(user:user!,auth:auth,data:data,onUserChanged:(u)=>setState(()=>user=u),onLogout:_logout,focusPlaceId:id):HomeScreen(user:user!,auth:auth,data:data,onUserChanged:(u)=>setState(()=>user=u),onLogout:_logout,focusPlaceId:id)));}else if(user!.isAdministrator){navigator.push(MaterialPageRoute(builder:(_)=>AdminHomeScreen(user:user!,auth:auth,data:data,onUserChanged:(u)=>setState(()=>user=u),onLogout:_logout)));}}


  @override
  void initState() {
    super.initState();
    auth = AuthRepository(local, client: widget.client);
    data = widget.client == null ? local : SupabaseRepository(widget.client!);
    PushNotificationService.instance.onOpened=_handleNotification;
    _startup();
  }

  Future<void> _startup() async {
    await _checkVersion();
    if (!updateRequired) await _restore();
  }

  Future<void> _checkVersion() async {
    try {
      final client=widget.client;
      if(client==null){if(mounted)setState(()=>versionChecked=true);return;}
      final row=await client.from('app_version_control').select('latest_version_code,update_url').eq('id',1).maybeSingle();
      final min=(row?['latest_version_code'] as num?)?.toInt()??currentVersionCode;
      updateUrl='${row?['update_url']??updateUrl}';
      final installedCode=int.tryParse((await PackageInfo.fromPlatform()).buildNumber)??currentVersionCode;
      if(mounted)setState((){updateRequired=installedCode<min;versionChecked=true;});
    } catch(e){debugPrint('Version check failed: $e');if(mounted)setState(()=>versionChecked=true);}
  }

  Future<void> _restore() async {
    try {
      user = await auth.currentUser();
    } catch (error, stackTrace) {
      debugPrint('Session restore failed; showing login: $error');
      debugPrintStack(stackTrace: stackTrace);
      user = null;
    } finally {
      if (mounted) {setState(() => ready = true);WidgetsBinding.instance.addPostFrameCallback((_)=>_openNotification());}
    }
  }

  Future<void> _logout() async {
    await PushNotificationService.instance.disableCurrentToken();
    await auth.logout();
    if (mounted) setState(() => user = null);
  }

  @override
  Widget build(BuildContext context) {
    Widget home;
    if (widget.startupError != null) {
      home = Scaffold(body: SafeArea(child: Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_outlined, size: 58),
          const SizedBox(height: 16),
          const Text('로그인 서버 연결 오류', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(widget.startupError!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          const Text('앱을 완전히 종료한 후 다시 실행해주세요. 계속 발생하면 이 화면을 보내주세요.', textAlign: TextAlign.center),
        ]),
      ))));
    } else if (!versionChecked) {
      home = const Scaffold(body: Center(child: CircularProgressIndicator()));
    } else if (updateRequired) {
      home = PopScope(
        canPop: false,
        child: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.system_update, size: 72),
                    const SizedBox(height: 20),
                    const Text(
                      '새 버전이 있습니다',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '새 버전이 출시되었습니다. 업데이트가 아직 제공되지 않으면 나중에 다시 확인해주세요.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse(updateUrl);
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        },
                        icon: const Icon(Icons.update),
                        label: const Text('업데이트하기'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(onPressed: () async {setState(() => updateRequired=false);await _restore();}, child: const Text('나중에 · 앱 계속 사용')),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } else if (!ready) {
      home = const Scaffold(body: Center(child: CircularProgressIndicator()));
    } else if (user == null) {
      home = LoginScreen(
        auth: auth,
        onLoggedIn: (u) {
          setState(() => user = u);
          WidgetsBinding.instance.addPostFrameCallback((_)=>_openNotification());
          PushNotificationService.instance.syncForSignedInUser();
        },
      );
    } else if (user!.isAdministrator) {
      home = AdminHomeScreen(
        user: user!,
        auth: auth,
        data: data,
        onUserChanged: (u) => setState(() => user = u),
        onLogout: _logout,
      );
    } else {
      home = HomeScreen(
        user: user!,
        auth: auth,
        data: data,
        onUserChanged: (u) => setState(() => user = u),
        onLogout: _logout,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_)=>_openNotification());
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: AppConfig.appName,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff1976d2)),
        useMaterial3: true,
      ),
      routes: {
        '/signup': (_) => SignupScreen(auth: auth),
        '/find-id': (_) => RecoveryScreen(auth: auth, mode: 'id'),
        '/find-pw': (_) => RecoveryScreen(auth: auth, mode: 'pw'),
      },
      home: home,
    );
  }
}
