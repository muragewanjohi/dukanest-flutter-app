class ApiException implements Exception {
  final String message;
  final String? code;
  final dynamic details;

  ApiException({required this.message, this.code, this.details});

  @override
  String toString() {
    return 'ApiException: $message (Code: $code)';
  }
}
