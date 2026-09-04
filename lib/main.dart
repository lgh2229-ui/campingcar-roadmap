import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/app_config.dart';
import 'models/app_user.dart';
import 'repositories/app_data_repository.dart';
import 'repositories/auth_repository.dart';
import 'repositories/local_repository.dart';
import 'repositories/supabase_repository.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/recovery_screen.dart';
import 'screens/signup_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SupabaseClient? client;
  if (AppConfig.serverEnabled) {
    await Supabase.initialize(url: AppConfig.supabaseUrl, publishableKey: AppConfig.supabaseKey);
    client = Supabase.instance.client;
  }
  runApp(CampingCarRoadmapApp(client: client));
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

  @override
  void initState() {
    super.initState();
    auth = AuthRepository(local, client: widget.client);
    data = widget.client == null ? local : SupabaseRepository(widget.client!);
    _restore();
  }

  Future<void> _restore() async {
    user = await auth.currentUser();
    if (mounted) setState(() => ready = true);
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
      home: !ready
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : user == null
              ? LoginScreen(auth: auth, onLoggedIn: (u) => setState(() => user = u))
              : HomeScreen(
                  user: user!,
                  auth: auth,
                  data: data,
                  onUserChanged: (u) => setState(() => user = u),
                  onLogout: () async {
                    await auth.logout();
                    if (mounted) setState(() => user = null);
                  },
                ),
    );
  }
}
