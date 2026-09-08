class Place {
  Place({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.services,
    required this.prices,
    this.hours = '',
    this.reservation = '',
    this.maxHeightMm,
    this.phone = '',
    this.note = '',
    this.status = 'ok',
    this.ownerId = '',
    this.photoUrls = const [],
    this.approvalStatus = 'pending',
  });

  final String id;
  String name;
  double latitude;
  double longitude;
  String address;
  List<String> services;
  Map<String, String> prices;
  String hours;
  String reservation;
  int? maxHeightMm;
  String phone;
  String note;
  String status;
  String ownerId;
  List<String> photoUrls;
  String approvalStatus;

  bool get hasHeightRestriction => maxHeightMm != null && maxHeightMm! > 0;
  bool get isApproved => approvalStatus == 'approved';
  bool get isPending => approvalStatus == 'pending';

  bool isHeightCompatible(int? vehicleHeightMm, {int clearanceBufferMm = 100}) {
    if (!hasHeightRestriction || vehicleHeightMm == null || vehicleHeightMm <= 0) return true;
    return vehicleHeightMm + clearanceBufferMm <= maxHeightMm!;
  }

  String heightSafetyLabel(int? vehicleHeightMm, {int clearanceBufferMm = 100}) {
    if (!hasHeightRestriction) return '높이 제한 정보 없음';
    final limit = (maxHeightMm! / 1000).toStringAsFixed(1);
    if (vehicleHeightMm == null || vehicleHeightMm <= 0) return '제한높이 ${limit}m · 차량 높이 미등록';
    final vehicle = (vehicleHeightMm / 1000).toStringAsFixed(1);
    if (isHeightCompatible(vehicleHeightMm, clearanceBufferMm: clearanceBufferMm)) return '통과 가능 예상 · 차량 ${vehicle}m / 제한 ${limit}m';
    return '진입 주의 · 차량 ${vehicle}m / 제한 ${limit}m';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'services': services,
        'prices': prices,
        'hours': hours,
        'reservation': reservation,
        'maxHeightMm': maxHeightMm,
        'phone': phone,
        'note': note,
        'status': status,
        'ownerId': ownerId,
        'photoUrls': photoUrls,
        'approvalStatus': approvalStatus,
      };

  Map<String, dynamic> toSupabaseJson() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'services': services,
        'prices': prices,
        'hours': hours,
        'reservation': reservation,
        'max_height_mm': maxHeightMm,
        'inquiry_phone': phone,
        'note': note,
        'status': status,
      };

  factory Place.fromJson(Map<String, dynamic> j) => Place(
        id: '${j['id']}',
        name: '${j['name'] ?? ''}',
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        address: '${j['address'] ?? ''}',
        services: List<String>.from(j['services'] ?? const []),
        prices: Map<String, String>.from(j['prices'] ?? const {}),
        hours: '${j['hours'] ?? ''}',
        reservation: '${j['reservation'] ?? ''}',
        maxHeightMm: (j['maxHeightMm'] ?? j['max_height_mm']) as int?,
        phone: '${j['phone'] ?? j['inquiry_phone'] ?? ''}',
        note: '${j['note'] ?? ''}',
        status: '${j['status'] ?? 'ok'}',
        ownerId: '${j['ownerId'] ?? j['owner_id'] ?? ''}',
        photoUrls: List<String>.from(j['photoUrls'] ?? j['photo_urls'] ?? const []),
        approvalStatus: '${j['approvalStatus'] ?? j['approval_status'] ?? 'pending'}',
      );
}
