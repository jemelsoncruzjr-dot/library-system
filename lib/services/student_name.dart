String studentFullName(Map<String, dynamic> data) {
  final first = (data['firstName'] ?? '').toString().trim();
  final last = (data['lastName'] ?? '').toString().trim();
  final combined = '$first $last'.trim();
  if (combined.isNotEmpty) return combined;
  return (data['fullName'] ?? data['name'] ?? data['displayName'] ?? 'Student')
      .toString()
      .trim();
}

bool isValidatedStudent(Map<String, dynamic> data) {
  return (data['validationStatus'] ?? '').toString() == 'validated';
}
