/// API error that preserves business [code] and field-level [fields] for form UX.
class ApiFieldException implements Exception {
  ApiFieldException(
    this.message, {
    this.code,
    this.fields,
    this.fieldIssues,
    this.nonField,
  });

  final String message;
  final String? code;
  final Map<String, dynamic>? fields;
  final Map<String, dynamic>? fieldIssues;
  final List<dynamic>? nonField;

  @override
  String toString() => message;
}
