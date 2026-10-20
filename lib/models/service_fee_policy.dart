import 'recreation_activities.dart';

/// Editing existing places: only fee-based facility tags need a price.
/// Check-only options (including EV charger) must save without a fee.
bool placeEditRequiresFee(String service) {
  const feeNotRequired = <String>{
    '제작','매매','수리','A/S','부품·용품',
    '전기차 충전기',
  };
  return !feeNotRequired.contains(service) &&
      !recreationActivities.contains(service);
}
