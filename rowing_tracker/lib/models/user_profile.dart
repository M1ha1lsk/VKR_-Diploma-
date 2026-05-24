class UserProfile {
  const UserProfile({
    required this.userId,
    this.login,
    this.passwordHash,
    this.maxHr,
    this.gender,
    this.theme,
    this.splitUnit,
    this.lastPrediction2k,
    this.lastPrediction2kDate,
  });

  final int userId;
  final String? login;
  final String? passwordHash;
  final int? maxHr;
  final String? gender;
  final String? theme;
  final String? splitUnit;
  final double? lastPrediction2k;
  final DateTime? lastPrediction2kDate;
}
