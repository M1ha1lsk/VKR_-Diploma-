class BackendRequestError implements Exception {
  BackendRequestError(this.message);
  final String message;

  @override
  String toString() => message;
}

class HealthBackendService {
  const HealthBackendService();

  Future<int> requestMaxHrFromAge(int age) async {
    if (age < 5 || age > 100) {
      throw BackendRequestError('Возраст должен быть в диапазоне 5–100.');
    }
    return 220 - age;
  }

  Future<int> requestManualMaxHr(int maxHr) async {
    if (maxHr < 80 || maxHr > 240) {
      throw BackendRequestError('Максимальный пульс должен быть в диапазоне 80–240.');
    }
    return maxHr;
  }
}
