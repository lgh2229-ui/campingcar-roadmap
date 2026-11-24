/// Search nearby restaurants in Naver Map using the actual shop name and
/// Korean city/town parsed from the address, never a third-party place URL.
/// e.g. 예촌사랑 충남 예산군 응봉면 -> "예촌사랑 예산 응봉면".
String nearbyFoodNaverSearchText(String name, String address) {
  final shop = name.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (shop.isEmpty) return '';
  final parts = address.trim()
      .replaceAll(RegExp(r'\([^)]*\)'), ' ')
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return shop;

  // Skip the province, special city or metropolitan city prefix.
  final province = RegExp(
    r'^(서울특별시|부산광역시|대구광역시|인천광역시|광주광역시|'
    r'대전광역시|울산광역시|세종특별자치시|'
    r'경기도|강원특별자치도|강원도|충청북도|충청남도|'
    r'전북특별자치도|전라북도|전라남도|경상북도|경상남도|'
    r'제주특별자치도|서울|부산|대구|인천|광주|대전|'
    r'울산|세종|경기|강원|충북|충남|전북|전남|경북|경남|제주)$',
  );
  final start = province.hasMatch(parts.first) ? 1 : 0;
  final administrativePart = RegExp(r'(시|군|구|읍|면|동|리|가)$');
  final region = <String>[];
  for (final part in parts.skip(start)) {
    if (!administrativePart.hasMatch(part)) break; // Stop at street/lot number.
    // "오산시" -> "오산", "예산군" -> "예산".
    final value = region.isEmpty
        ? part.replaceFirst(RegExp(r'(시|군)$'), '')
        : part;
    if (value.isNotEmpty) region.add(value);
    if (region.length == 3) break;
  }
  if (region.isEmpty) {
    // If address is unusual, favor shop + city over just the bare name.
    return '$shop ${parts.skip(start).take(2).join(' ')}'.trim();
  }
  return '$shop ${region.join(' ')}';
}

/// Official Naver Map app URL scheme. On Android this requests a place search,
/// not an arbitrary coordinate pin ("unknown place").
Uri nearbyFoodNaverAppUri(String name, String address) => Uri(
  scheme: 'nmap',
  host: 'search',
  queryParameters: {
    'query': nearbyFoodNaverSearchText(name, address),
    'appname': 'kr.co.campingcarroadmap.app',
  },
);

/// Web fallback uses the same complete search phrase.
Uri nearbyFoodNaverWebUri(String name, String address) => Uri.parse(
  'https://map.naver.com/p/search/'
  '${Uri.encodeComponent(nearbyFoodNaverSearchText(name, address))}',
);
