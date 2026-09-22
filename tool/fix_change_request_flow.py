from pathlib import Path

# This project now keeps the change-request functionality in the source tree.
# Older builds patched exact UI text here and failed whenever the admin screen
# was redesigned. Keep this workflow step idempotent: only apply safe legacy
# model changes when missing, and never abort the build because UI text moved.

p = Path('lib/models/place.dart')
s = p.read_text()
if 'String requestType;' not in s:
    s = s.replace("    this.approvalStatus = 'pending',\n  });", "    this.approvalStatus = 'pending',\n    this.requestType = 'new',\n    this.targetPlaceId = '',\n  });", 1)
    s = s.replace("  String approvalStatus;\n", "  String approvalStatus;\n  String requestType;\n  String targetPlaceId;\n", 1)
    s = s.replace("        'approvalStatus': approvalStatus,\n", "        'approvalStatus': approvalStatus,\n        'requestType': requestType,\n        'targetPlaceId': targetPlaceId,\n", 1)
    s = s.replace("        'status': status,\n      };", "        'status': status,\n        'request_type': requestType,\n        'target_place_id': targetPlaceId.isEmpty ? null : targetPlaceId,\n      };", 1)
    s = s.replace("        approvalStatus: '${j['approvalStatus'] ?? j['approval_status'] ?? 'pending'}',\n      );", "        approvalStatus: '${j['approvalStatus'] ?? j['approval_status'] ?? 'pending'}',\n        requestType: '${j['requestType'] ?? j['request_type'] ?? 'new'}',\n        targetPlaceId: '${j['targetPlaceId'] ?? j['target_place_id'] ?? ''}',\n      );", 1)
    p.write_text(s)

# Do not patch repository/admin/home screens by fragile exact text anymore.
# Their current implementations are authoritative and subsequent workflow
# patchers may safely add any still-needed behavior.
print('change-request compatibility patch: OK')
