import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../repositories/auth_repository.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key, required this.auth});
  final AuthRepository auth;
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final id = TextEditingController();
  final phone = TextEditingController();
  final sms = TextEditingController();
  final pw = TextEditingController();
  final pwConfirm = TextEditingController();
  final vehicleName = TextEditingController();
  final vehicleHeight = TextEditingController();
  String vehicleStatus = 'planned';
  String sanitation = '';
  String? testCode;
  bool started = false;
  bool verified = false;
  bool busy = false;

  Future<void> _send() async {
    if (!RegExp(r'^[A-Za-z0-9_]{4,20}$').hasMatch(id.text.trim())) return _msg('아이디는 영문/숫자/밑줄 4~20자로 입력해주세요.');
    if (!widget.auth.validPassword(pw.text)) return _msg('비밀번호는 영문+숫자+특수문자 포함 8~20자입니다.');
    if (pw.text != pwConfirm.text) return _msg('비밀번호와 비밀번호 확인이 일치하지 않습니다.');
    if (widget.auth.normalizePhone(phone.text).length < 10) return _msg('휴대폰 번호를 확인해주세요.');
    if (vehicleStatus == 'owned') {
      if (vehicleName.text.trim().isEmpty) return _msg('보유 차량의 차량명/모델을 입력해주세요.');
      if (int.tryParse(vehicleHeight.text.trim()) == null) return _msg('차량 높이를 mm 단위 숫자로 입력해주세요.');
      if (sanitation.isEmpty) return _msg('위생설비 종류를 선택해주세요.');
    }
    setState(() => busy = true);
    try {
      if (widget.auth.serverEnabled) {
        if (!started) {
          await widget.auth.beginServerSignup(
            userId: id.text.trim(),
            password: pw.text,
            phone: phone.text,
            vehicleStatus: vehicleStatus,
            vehicleName: vehicleStatus == 'owned' ? vehicleName.text.trim() : '',
            vehicleHeightMm: vehicleStatus == 'owned' ? int.tryParse(vehicleHeight.text.trim()) : null,
            sanitation: vehicleStatus == 'owned' ? sanitation : '',
          );
        } else {
          await widget.auth.resendServerSignupOtp(phone.text);
        }
        setState(() { started = true; verified = false; });
        _msg('등록한 휴대폰으로 인증번호를 보냈습니다.');
      } else {
        final code = await widget.auth.sendMockSms(phone.text);
        setState(() { testCode = code; started = true; verified = false; });
      }
    } catch (e) {
      _msg(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _verify() async {
    if (!started) return _msg('인증번호를 먼저 받아주세요.');
    try {
      if (widget.auth.serverEnabled) {
        await widget.auth.verifyServerSignupPhone(phone.text, sms.text);
        verified = true;
      } else {
        verified = widget.auth.verifySms(phone.text, sms.text);
        if (verified) {
          await widget.auth.signup(AppUser(
            userId: id.text.trim(),
            password: pw.text,
            phone: phone.text.trim(),
            phoneVerified: true,
            vehicleStatus: vehicleStatus,
            vehicleName: vehicleStatus == 'owned' ? vehicleName.text.trim() : '',
            vehicleHeightMm: vehicleStatus == 'owned' ? int.tryParse(vehicleHeight.text.trim()) : null,
            sanitationType: vehicleStatus == 'owned' ? sanitation : '',
          ));
        }
      }
      if (!verified) return _msg('인증번호가 일치하지 않습니다.');
      if (!mounted) return;
      setState(() {});
      _msg('휴대폰 인증과 회원가입이 완료되었습니다.');
      Navigator.pop(context);
    } catch (e) {
      _msg(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _msg(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('회원가입')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      TextField(controller: id, enabled: !started, decoration: const InputDecoration(labelText: '아이디', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: pw, enabled: !started, obscureText: true, decoration: const InputDecoration(labelText: '비밀번호', hintText: '영문+숫자+특수문자 8~20자', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: pwConfirm, enabled: !started, obscureText: true, decoration: const InputDecoration(labelText: '비밀번호 확인', border: OutlineInputBorder())),
      const SizedBox(height: 18),
      const Text('차량정보', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      const SizedBox(height: 4),
      RadioListTile<String>(
        value: 'planned',
        groupValue: vehicleStatus,
        onChanged: started ? null : (v) => setState(() => vehicleStatus = v!),
        title: const Text('구매예정'),
        contentPadding: EdgeInsets.zero,
      ),
      RadioListTile<String>(
        value: 'owned',
        groupValue: vehicleStatus,
        onChanged: started ? null : (v) => setState(() => vehicleStatus = v!),
        title: const Text('보유중'),
        contentPadding: EdgeInsets.zero,
      ),
      if (vehicleStatus == 'owned') ...[
        TextField(controller: vehicleName, enabled: !started, decoration: const InputDecoration(labelText: '차량명/모델', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: vehicleHeight, enabled: !started, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '차량 높이(mm)', hintText: '예: 3000', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        const Text('위생설비'),
        ...['블랙탱크', '그레이탱크', '카트리지'].map((e) => RadioListTile<String>(
          value: e,
          groupValue: sanitation,
          onChanged: started ? null : (v) => setState(() => sanitation = v!),
          title: Text(e),
          contentPadding: EdgeInsets.zero,
        )),
      ],
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: TextField(controller: phone, enabled: !started, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: '휴대폰 번호', border: OutlineInputBorder()))),
        const SizedBox(width: 8),
        FilledButton(onPressed: busy ? null : _send, child: Text(started ? '재전송' : '인증번호')),
      ]),
      if (testCode != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('개발용 인증번호: $testCode')),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: TextField(controller: sms, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '인증번호', border: OutlineInputBorder()))),
        const SizedBox(width: 8),
        OutlinedButton(onPressed: _verify, child: const Text('확인')),
      ]),
      if (widget.auth.serverEnabled) const Padding(padding: EdgeInsets.only(top: 12), child: Text('실제 SMS 인증 모드', style: TextStyle(fontSize: 12))),
    ]),
  );
}
