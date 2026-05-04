class SolaError implements Exception {
  final String message;

  SolaError(this.message);

  @override
  String toString() => message;
}
