
class IncompleteProfileException implements Exception {
  final String message;

  IncompleteProfileException(this.message);

  @override
  String toString() => message;
}
