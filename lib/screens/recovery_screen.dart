import 'package:flutter/material.dart';
import '../repositories/auth_repository.dart';

class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key, required this.auth, required this.mode});
  final AuthRepository auth;
  final String mode;
  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  final id = TextEditingController();
  final phone = TextEditingController();
  final sms = TextEditingController();
  final newPw = TextEditingController();
  String? code;
  bool verified = false;
  String? foundId;

  Future<void> _send() async {
    try {
      if (widget.auth.serverEnabled) {
        await widget.auth.sendRecoveryOtp(phone.text);
        code = 'sent';
      } else {
        if (widget.mode == 'id') {
          final found = await widget.auth.findIdByPhone(phone.text);
          if (found == null) return _msg('등록된 계정을 찾을 수 없습니다.');
          foundId = found;
        }
        code = await widget.auth.sendMockSms(phone.text);
      }
      setState(() {});
      _msg(widget.auth.serverEnabled ? '등록된 휴대폰으로 인증번호를 보냈습니다.' : '개발용 인증번호가 생성되었습니다.');
    } catch (e) {
      _msg('등록된 휴대폰 번호인지 확인해주세요.');
    }
  }

  Future<void> _verify() async {
    try {
      if (widget.auth.serverEnabled) {
        await widget.auth.verifyRecoveryOtp(phone.text, sms.text);
        verified = true;
        if (widget.mode == 'id') foundId = await widget.auth.findIdByPhone(phone.text);
      } else {
        verified = widget.auth.verifySms(phone.text, sms.text);
      }
      if (!verified) return _msg('인증번호가 일치하지 않습니다.');
      setState(() {});
    } catch (_) {
      _msg('인증번호가 일치하지 않거나 만료되었습니다.');
    }
  }

  Future<void> _reset() async {
    if (!verified) return _msg('휴대폰 인증을 완료해주세요.');
    if (!widget.auth.validPassword(newPw.text)) return _msg('새 비밀번호 규칙을 확인해주세요.');
    final ok = await widget.auth.resetPassword(id.text.trim(), phone.text, newPw.text);
    if (!ok) return _msg('아이디와 등록된 휴대폰 번호가 일치하지 않습니다.');
    if (!mounted) return;
    await widget.auth.logout();
    Navigator.pop(context);
    _msg('비밀번호가 변경되었습니다. 새 비밀번호로 로그인해주세요.');
  }

  void _msg(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  @override
  Widget build(BuildContext context) {
    final findId = widget.mode == 'id';
    return Scaffold(
      appBar: AppBar(title: Text(findId ? '아이디 찾기' : '비밀번호 찾기')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        if (!findId) ...[
          TextField(controller: id, decoration: const InputDecoration(labelText: '아이디', border: OutlineInputBorder())),
          const SizedBox(height: 12),
        ],
        TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: '등록된 휴대폰 번호', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        FilledButton(onPressed: _send, child: const Text('인증번호 받기')),
        if (!widget.auth.serverEnabled && code != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('개발용 인증번호: $code')),
        const SizedBox(height: 8),
        TextField(controller: sms, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '인증번호', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: _verify, child: Text(verified ? '인증 완료' : '인증 확인')),
        if (findId && verified && foundId != null)
          Card(child: Padding(padding: const EdgeInsets.all(18), child: Text('가입 아이디: $foundId', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))),
        if (!findId && verified) ...[
          const SizedBox(height: 12),
          TextField(controller: newPw, obscureText: true, decoration: const InputDecoration(labelText: '새 비밀번호', hintText: '영문+숫자+특수문자 8~20자', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          FilledButton(onPressed: _reset, child: const Text('비밀번호 변경')),
        ],
      ]),
    );
  }
}
