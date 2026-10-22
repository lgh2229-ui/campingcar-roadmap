/// Activity tags stored in the existing Place.services array.
/// They represent information submitted for a place, not a guarantee of
/// access, permission, safety, or opening hours.
const List<String> recreationActivities = <String>[
  '관광지',
  '산책',
  '등산',
  '낚시',
  '해루질',
  '수상레포츠',
  '지상레포츠',
  '카지노',
  '수영',
  '서핑',
  '카약·SUP',
  '스노클링',
  '온천·스파',
  '문화체험',
  '시장·쇼핑',
];

/// Legacy category tags remain stored for older registrations, but are not
/// independent categories in the 3km nearby-tourism card grid.
const Set<String> mergedOrNonTourismActivities = <String>{
  '자전거', '스키·눈썰매', '골프', '캠핑장',
};
