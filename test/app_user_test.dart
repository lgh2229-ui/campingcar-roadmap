import 'package:flutter_test/flutter_test.dart';
import 'package:campingcar_roadmap/models/app_user.dart';

void main() {
  test('administrator requires both admin role and administrator id', () {
    expect(AppUser(userId: 'administrator', phone: '', role: 'admin').isAdministrator, isTrue);
    expect(AppUser(userId: 'administrator', phone: '', role: 'user').isAdministrator, isFalse);
    expect(AppUser(userId: 'someone', phone: '', role: 'admin').isAdministrator, isFalse);
  });

  test('Supabase vehicle fields are parsed', () {
    final user = AppUser.fromJson({
      'username': 'camper1',
      'phone': '01012345678',
      'vehicle_status': 'owned',
      'vehicle_name': '누리고 with 칸',
      'vehicle_height_mm': 3000,
      'sanitation_type': '블랙탱크',
    });
    expect(user.vehicleHeightMm, 3000);
    expect(user.sanitationType, '블랙탱크');
  });
}
