import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_user.dart';
import 'local_repository.dart';

class AuthRepository {
  AuthRepository(this.local, {this.client});
  final LocalRepository local;
  final SupabaseClient? client;
  final Map<String, String> _smsCodes = {};

  bool get serverEnabled => client != null;
  String normalizePhone(String v) => v.replaceAll(RegExp(r'[^0-9]'), '');
  String toE164(String v) { final n = normalizePhone(v); if (n.startsWith('82')) return '+$n'; if (n.startsWith('0')) return '+82${n.substring(1)}'; return '+82$n'; }
  String loginEmail(String userId) => '${userId.trim().toLowerCase()}@login.campingcarroadmap.invalid';
  bool validPassword(String v) => v.length >= 8 && v.length <= 20 && RegExp(r'[A-Za-z]').hasMatch(v) && RegExp(r'[0-9]').hasMatch(v) && RegExp(r'[^A-Za-z0-9]').hasMatch(v);

  Future<String> sendMockSms(String phone) async { final code = (100000 + Random().nextInt(900000)).toString(); _smsCodes[normalizePhone(phone)] = code; return code; }
  bool verifySms(String phone, String code) => _smsCodes[normalizePhone(phone)] == code.trim();

  Future<AppUser?> login(String userId, String password, {bool administratorMode = false}) async {
    AppUser? u;
    if (!serverEnabled) {
      final users = await local.users();
      for (final x in users) { if (x.userId.toLowerCase() == userId.toLowerCase() && x.password == password) { u = x; break; } }
      if (u != null) await local.setSession(u.userId);
    } else {
      try {
        final res = await client!.functions.invoke('login-by-username', body: {'username': userId.trim(), 'password': password});
        final data = res.data;
        if (data is! Map || data['ok'] != true || '${data['refresh_token'] ?? ''}'.isEmpty) return null;
        await client!.auth.setSession('${data['refresh_token']}');
        u = await currentUser();
      } catch (_) {
        return null;
      }
    }
    if (u == null) return null;
    if (administratorMode && !u.isAdministrator) { await logout(); return null; }
    if (!administratorMode && u.isAdministrator) { await logout(); return null; }
    return u;
  }

  Future<void> logout() async { if (serverEnabled) { await client!.auth.signOut(); } else { await local.setSession(null); } }

  Future<void> signup(AppUser user) async {
    if (serverEnabled) throw UnsupportedError('서버 모드에서는 beginServerSignup/verifyServerSignupPhone을 사용합니다.');
    final users = await local.users();
    if (users.any((u) => u.userId.toLowerCase() == user.userId.toLowerCase())) throw Exception('이미 사용 중인 아이디입니다.');
    if (user.nickname.trim().isEmpty) throw Exception('닉네임은 필수입니다.');
    users.add(user); await local.saveUsers(users);
  }

  Future<void> beginServerSignup({required String userId, required String password, required String phone, required String nickname, String vehicleStatus = 'planned', String vehicleName = '', int? vehicleHeightMm, String sanitation = ''}) async {
    if (!serverEnabled) return;
    final id = userId.trim();
    if (id.toLowerCase() == 'administrator') throw Exception('administrator 아이디는 관리자 전용이라 일반 회원가입으로 만들 수 없습니다.');
    if (!RegExp(r'^[A-Za-z0-9_]{4,20}$').hasMatch(id)) throw Exception('아이디는 영문/숫자/밑줄 4~20자로 입력해주세요.');
    if (!validPassword(password)) throw Exception('비밀번호 규칙을 확인해주세요.');
    if (nickname.trim().isEmpty || nickname.trim().length > 20) throw Exception('닉네임은 1~20자로 입력해주세요.');
    if (vehicleStatus == 'owned') {
      if (vehicleName.trim().isEmpty) throw Exception('보유 차량의 차량명/모델을 입력해주세요.');
      if (vehicleHeightMm == null || vehicleHeightMm <= 0) throw Exception('차량 높이를 입력해주세요.');
      if (sanitation.isEmpty) throw Exception('위생설비 종류를 선택해주세요.');
    }

    final res = await client!.auth.signUp(
      phone: toE164(phone),
      password: password,
      data: {
        'username': id,
        'nickname': nickname.trim(),
        'vehicle_status': vehicleStatus,
        'vehicle_name': vehicleStatus == 'owned' ? vehicleName.trim() : '',
        'vehicle_height_mm': vehicleStatus == 'owned' ? vehicleHeightMm : null,
        'sanitation_type': vehicleStatus == 'owned' ? sanitation : '',
      },
    );
    if (res.user == null) throw Exception('회원 계정을 만들지 못했습니다.');
  }

  Future<void> resendServerSignupOtp(String phone) async {
    if (!serverEnabled) return;
    await client!.auth.signInWithOtp(phone: toE164(phone), shouldCreateUser: false);
  }

  Future<void> verifyServerSignupPhone(String phone, String token) async {
    if (!serverEnabled) return;
    final response = await client!.auth.verifyOTP(type: OtpType.sms, phone: toE164(phone), token: token.trim());
    final uid = response.user?.id ?? client!.auth.currentUser?.id;
    if (uid == null) throw Exception('휴대폰 인증 세션을 확인할 수 없습니다.');
    await client!.from('profiles').update({'phone_verified': true, 'phone': normalizePhone(phone)}).eq('id', uid);
  }

  Future<AppUser?> currentUser() async {
    if (!serverEnabled) { final id = await local.sessionUserId(); if (id == null) return null; final users = await local.users(); for (final u in users) { if (u.userId == id) return u; } return null; }
    final authUser = client!.auth.currentUser; if (authUser == null) return null;
    final row = await client!.from('profiles').select().eq('id', authUser.id).maybeSingle(); if (row == null) return null;
    return AppUser.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> sendRecoveryOtp(String phone) async { if (serverEnabled) await client!.auth.signInWithOtp(phone: toE164(phone), shouldCreateUser: false); }
  Future<void> verifyRecoveryOtp(String phone, String token) async { if (serverEnabled) await client!.auth.verifyOTP(type: OtpType.sms, phone: toE164(phone), token: token.trim()); }
  Future<String?> findIdByPhone(String phone) async { if (!serverEnabled) { final normalized = normalizePhone(phone); for (final u in await local.users()) { if (normalizePhone(u.phone) == normalized) return u.userId; } return null; } final u = await currentUser(); if (u == null || normalizePhone(u.phone) != normalizePhone(phone)) return null; return u.userId; }
  Future<bool> resetPassword(String userId, String phone, String newPassword) async { if (!serverEnabled) { final users = await local.users(); for (final u in users) { if (u.userId.toLowerCase() == userId.toLowerCase() && normalizePhone(u.phone) == normalizePhone(phone)) { u.password = newPassword; await local.saveUsers(users); return true; } } return false; } final profile = await currentUser(); if (profile == null || profile.userId.toLowerCase() != userId.toLowerCase() || normalizePhone(profile.phone) != normalizePhone(phone)) return false; await client!.auth.updateUser(UserAttributes(password: newPassword)); return true; }
  Future<bool> reauthenticatePassword(String password) async {
    final profile = await currentUser(); if (profile == null) return false;
    if (!serverEnabled) return profile.password == password;
    try {
      final res = await client!.functions.invoke('login-by-username', body: {'username': profile.userId, 'password': password});
      final data = res.data;
      return data is Map && data['ok'] == true;
    } catch (_) { return false; }
  }

  Future<AppUser> updateVehicle({required String status, required String name, required int? heightMm, required String sanitation}) async {
    final profile = await currentUser(); if (profile == null) throw Exception('로그인이 필요합니다.');
    profile.vehicleStatus = status; profile.vehicleName = name; profile.vehicleHeightMm = heightMm; profile.sanitationType = sanitation;
    if (!serverEnabled) { final users = await local.users(); final i = users.indexWhere((u) => u.userId == profile.userId); if (i >= 0) users[i] = profile; await local.saveUsers(users); return profile; }
    await client!.from('profiles').update({'vehicle_status': status, 'vehicle_name': name, 'vehicle_height_mm': heightMm, 'sanitation_type': sanitation}).eq('id', client!.auth.currentUser!.id);
    return (await currentUser())!;
  }

  Future<void> deleteAccount() async {
    if (!serverEnabled) { final profile = await currentUser(); if (profile == null) return; final users = await local.users(); users.removeWhere((u) => u.userId == profile.userId); await local.saveUsers(users); await local.setSession(null); return; }
    final session = client!.auth.currentSession; if (session == null) throw Exception('로그인이 필요합니다.');
    final res = await client!.functions.invoke('delete-account', headers: {'Authorization': 'Bearer ${session.accessToken}'}); final data = res.data; if (data is Map && data['ok'] != true) throw Exception('${data['error'] ?? '회원탈퇴 처리에 실패했습니다.'}'); await client!.auth.signOut();
  }
}
