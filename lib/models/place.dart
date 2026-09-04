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
      );
}
