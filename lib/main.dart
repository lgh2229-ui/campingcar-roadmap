import 'package:flutter/material.dart';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The first Flutter frame must never depend on a network/service startup.
  // If Supabase initialization fails for any reason, start with the local
  // repository instead of terminating before runApp().
  SupabaseClient? client;
  if (AppConfig.serverEnabled) {
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        publishableKey: AppConfig.supabaseKey,
      );
      client = Supabase.instance.client;
    } catch (error, stackTrace) {
      debugPrint('Supabase startup failed; continuing locally: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  runApp(CampingCarRoadmapApp(client: client));

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
  const CampingCarRoadmapApp({super.key, this.client});
  final SupabaseClient? client;
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
  static const int currentVersionCode = 122;

  @override
  void initState() {
    super.initState();
    auth = AuthRepository(local, client: widget.client);
    data = widget.client == null ? local : SupabaseRepository(widget.client!);
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
      final row=await client.from('app_version_control').select('min_version_code,update_url').eq('id',1).maybeSingle();
      final min=(row?['min_version_code'] as num?)?.toInt()??currentVersionCode;
      updateUrl='${row?['update_url']??updateUrl}';
      if(mounted)setState((){updateRequired=currentVersionCode<min;versionChecked=true;});
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
      if (mounted) setState(() => ready = true);
    }
  }

  Future<void> _logout() async {
    await PushNotificationService.instance.disableCurrentToken();
    await auth.logout();
    if (mounted) setState(() => user = null);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppConfig.appName,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff1976d2)), useMaterial3: true),
      routes: {
        '/signup': (_) => SignupScreen(auth: auth),
        '/find-id': (_) => RecoveryScreen(auth: auth, mode: 'id'),
        '/find-pw': (_) => RecoveryScreen(auth: auth, mode: 'pw'),
      },
      home: !versionChecked
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : updateRequired
              ? PopScope(canPop:false,child:Scaffold(body:SafeArea(child:Center(child:Padding(padding:const EdgeInsets.all(28),child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.system_update,size:72),const SizedBox(height:20),const Text('최신 버전 업데이트가 필요합니다',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold),textAlign:TextAlign.center),const SizedBox(height:10),const Text('캠핑카족 로드맵을 계속 사용하려면 최신 버전으로 업데이트해주세요.',textAlign:TextAlign.center),const SizedBox(height:24),SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:()async{final u=Uri.parse(updateUrl);await launchUrl(u,mode:LaunchMode.externalApplication);},icon:const Icon(Icons.update),label:const Text('업데이트하기'))]))))))
          : !ready
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : user == null
              ? LoginScreen(auth: auth, onLoggedIn: (u) { setState(() => user = u); PushNotificationService.instance.syncForSignedInUser(); })
              : user!.isAdministrator
                  ? AdminHomeScreen(
                      user: user!,
                      auth: auth,
                      data: data,
                      onUserChanged: (u) => setState(() => user = u),
                      onLogout: _logout,
                    )
                  : HomeScreen(
                      user: user!,
                      auth: auth,
                      data: data,
                      onUserChanged: (u) => setState(() => user = u),
                      onLogout: _logout,
                    ),
    );
  }
}
