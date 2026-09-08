class AppUser {
  AppUser({
    required this.userId,
    this.password = '',
    required this.phone,
    this.nickname = '',
    this.authId = '',
    this.role = 'user',
    this.phoneVerified = false,
    this.vehicleStatus = '',
    this.vehicleName = '',
    this.vehicleHeightMm,
    this.sanitationType = '',
  });

  final String userId;
  String password;
  String phone;
  String nickname;
  String authId;
  String role;
  bool phoneVerified;
  String vehicleStatus;
  String vehicleName;
  int? vehicleHeightMm;
  String sanitationType;

  bool get isAdministrator => role == 'admin' && userId.toLowerCase() == 'administrator';
  String get displayName => nickname.trim().isEmpty ? userId : nickname.trim();

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'password': password,
        'phone': phone,
        'nickname': nickname,
        'authId': authId,
        'role': role,
        'phoneVerified': phoneVerified,
        'vehicleStatus': vehicleStatus,
        'vehicleName': vehicleName,
        'vehicleHeightMm': vehicleHeightMm,
        'sanitationType': sanitationType,
      };

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        userId: '${j['userId'] ?? j['username'] ?? ''}',
        password: '${j['password'] ?? ''}',
        phone: '${j['phone'] ?? ''}',
        nickname: '${j['nickname'] ?? ''}',
        authId: '${j['authId'] ?? j['id'] ?? ''}',
        role: '${j['role'] ?? 'user'}',
        phoneVerified: j['phoneVerified'] == true || j['phone_verified'] == true,
        vehicleStatus: '${j['vehicleStatus'] ?? j['vehicle_status'] ?? ''}',
        vehicleName: '${j['vehicleName'] ?? j['vehicle_name'] ?? ''}',
        vehicleHeightMm: (j['vehicleHeightMm'] ?? j['vehicle_height_mm']) as int?,
        sanitationType: '${j['sanitationType'] ?? j['sanitation_type'] ?? ''}',
      );
}
