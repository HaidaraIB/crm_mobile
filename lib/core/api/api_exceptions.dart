/// API error that preserves business [code] and field-level [fields] for form UX.
class ApiFieldException implements Exception {
  ApiFieldException(
    this.message, {
    this.code,
    this.fields,
  });

  final String message;
  final String? code;
  final Map<String, dynamic>? fields;

  @override
  String toString() => message;
}
