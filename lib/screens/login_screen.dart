import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../repositories/auth_repository.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.auth, required this.onLoggedIn});
  final AuthRepository auth;
  final ValueChanged<AppUser> onLoggedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final id = TextEditingController();
  final pw = TextEditingController();
  bool administratorMode = false;
  bool loginInProgress = false;
  String? loginError;

  Future<void> _login() async {
    if (loginInProgress) return;
    setState(() {
      loginInProgress = true;
      loginError = null;
    });
    try {
      final u = await widget.auth.login(
        id.text.trim(), pw.text, administratorMode: administratorMode,
      );
      if (!mounted) return;
      if (u == null) {
        final message = widget.auth.lastLoginError ?? '로그인을 완료하지 못했습니다. 잠시 후 다시 시도해주세요.';
        setState(() => loginError = message);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      } else {
        widget.onLoggedIn(u);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => loginError = '로그인 처리 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loginError!)),
      );
    } finally {
      if (mounted) setState(() => loginInProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('🚐', textAlign: TextAlign.center, style: TextStyle(fontSize: 54)),
                const SizedBox(height: 8),
                Text('캠핑카족 로드맵', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 28),
                TextField(controller: id, decoration: const InputDecoration(labelText: '아이디', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: pw, obscureText: true, onSubmitted: (_) => _login(), decoration: const InputDecoration(labelText: '비밀번호', border: OutlineInputBorder())),
                CheckboxListTile(value: administratorMode, onChanged: (v) => setState(() => administratorMode = v == true), contentPadding: EdgeInsets.zero, title: const Text('관리자 모드로 로그인'), subtitle: const Text('관리자 계정만 사용할 수 있습니다.')),
                const SizedBox(height: 8),
                if (loginError != null) Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(loginError!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13),
                  ),
                ),
                FilledButton(
                  onPressed: loginInProgress ? null : _login,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: loginInProgress
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('로그인'),
                  ),
                ),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  TextButton(onPressed: () => Navigator.pushNamed(context, '/find-id'), child: const Text('아이디 찾기')),
                  const Text('|'),
                  TextButton(onPressed: () => Navigator.pushNamed(context, '/find-pw'), child: const Text('비밀번호 찾기')),
                ]),
                OutlinedButton(onPressed: () => Navigator.pushNamed(context, '/signup'), child: const Text('회원가입')),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
