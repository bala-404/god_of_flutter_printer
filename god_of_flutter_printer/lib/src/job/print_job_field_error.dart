/// A single validation problem on a [PrintJobSpec] field.
class PrintJobFieldError {
  const PrintJobFieldError({
    required this.field,
    required this.message,
  });

  final String field;
  final String message;

  @override
  String toString() => '$field: $message';
}

/// Outcome of synchronous [PrintJobValidator] checks (no I/O).
class PrintJobValidationResult {
  const PrintJobValidationResult._({
    required this.isValid,
    this.errors = const [],
  });

  final bool isValid;
  final List<PrintJobFieldError> errors;

  static const valid = PrintJobValidationResult._(isValid: true);

  factory PrintJobValidationResult.invalid(List<PrintJobFieldError> errors) {
    return PrintJobValidationResult._(isValid: false, errors: errors);
  }

  String get message => errors.map((e) => e.toString()).join('; ');
}
