from pathlib import Path

# Patch AuthRepository with profile update support.
p = Path('lib/repositories/auth_repository.dart')
s = p.read_text()
marker = "  Future<AppUser> updateVehicle({required String status, required String name, required int? heightMm, required String sanitation}) async {"
if "Future<AppUser> updateProfile({required String nickname" not in s:
    method = r'''  Future<AppUser> updateProfile({required String nickname, String? newPassword}) async {
    final profile = await currentUser();
    if (profile == null) throw Exception('로그인이 필요합니다.');
    final nick = nickname.trim();
    if (nick.isEmpty || nick.length > 20) throw Exception('닉네임은 1~20자로 입력해주세요.');
    final password = (newPassword ?? '').trim();
    if (password.isNotEmpty && !validPassword(password)) {
      throw Exception('새 비밀번호는 영문, 숫자, 특수문자를 포함한 8~20자로 입력해주세요.');
    }
    if (!serverEnabled) {
      final users = await local.users();
      final i = users.indexWhere((u) => u.userId == profile.userId);
      if (i < 0) throw Exception('사용자 정보를 찾을 수 없습니다.');
      users[i].nickname = nick;
      if (password.isNotEmpty) users[i].password = password;
      await local.saveUsers(users);
      return users[i];
    }
    await client!.from('profiles').update({'nickname': nick}).eq('id', client!.auth.currentUser!.id);
    if (password.isNotEmpty) {
      await client!.auth.updateUser(UserAttributes(password: password));
    }
    return (await currentUser())!;
  }

'''
    s = s.replace(marker, method + marker)
p.write_text(s)

# Patch HomeScreen password gate so successful verification opens an edit UI.
p = Path('lib/screens/home_screen.dart')
s = p.read_text()
start = s.index('  Future<void> _passwordGate() async {')
end = s.index('  Future<void> _deleteAccount() async {', start)
method = r'''  Future<void> _passwordGate() async {
    final c = TextEditingController();
    final entered = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('비밀번호 확인'),
        content: TextField(
          controller: c,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: '현재 비밀번호'),
          onSubmitted: (_) => Navigator.pop(ctx, c.text),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('확인')),
        ],
      ),
    );
    if (entered == null) return;
    final ok = await widget.auth.reauthenticatePassword(entered);
    if (!ok) return _msg('비밀번호가 일치하지 않습니다.');
    if (!mounted) return;
    await _profileEditDialog();
  }

  Future<void> _profileEditDialog() async {
    final nickname = TextEditingController(text: widget.user.nickname);
    final newPassword = TextEditingController();
    final confirmPassword = TextEditingController();
    bool savingProfile = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('개인정보 변경'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(enabled: false, controller: TextEditingController(text: widget.user.userId), decoration: const InputDecoration(labelText: '아이디')),
                TextField(enabled: false, controller: TextEditingController(text: widget.user.phone), decoration: const InputDecoration(labelText: '휴대폰 번호')),
                const SizedBox(height: 8),
                TextField(controller: nickname, enabled: !savingProfile, maxLength: 20, decoration: const InputDecoration(labelText: '닉네임')),
                TextField(controller: newPassword, enabled: !savingProfile, obscureText: true, decoration: const InputDecoration(labelText: '새 비밀번호 (변경할 때만 입력)')),
                TextField(controller: confirmPassword, enabled: !savingProfile, obscureText: true, decoration: const InputDecoration(labelText: '새 비밀번호 확인')),
                const SizedBox(height: 6),
                const Text('휴대폰 번호 변경은 재인증 기능이 추가된 뒤 제공됩니다.', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: savingProfile ? null : () => Navigator.pop(ctx), child: const Text('취소')),
            FilledButton(
              onPressed: savingProfile ? null : () async {
                final nick = nickname.text.trim();
                if (nick.isEmpty) return _msg('닉네임을 입력해주세요.');
                if (newPassword.text.isNotEmpty && newPassword.text != confirmPassword.text) {
                  return _msg('새 비밀번호 확인이 일치하지 않습니다.');
                }
                setS(() => savingProfile = true);
                try {
                  final updated = await widget.auth.updateProfile(nickname: nick, newPassword: newPassword.text);
                  widget.onUserChanged(updated);
                  if (ctx.mounted) Navigator.pop(ctx);
                  _msg('개인정보가 변경되었습니다.');
                } catch (e) {
                  _msg('개인정보 변경에 실패했습니다: $e');
                  if (ctx.mounted) setS(() => savingProfile = false);
                }
              },
              child: savingProfile
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

'''
s = s[:start] + method + s[end:]
p.write_text(s)
