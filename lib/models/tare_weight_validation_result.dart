class TareWeightValidationResult {
  final bool isValid;
  final String? errorMessage;
  final String? warningMessage;
  final double validatedValue;
  
  const TareWeightValidationResult({
    required this.isValid,
    this.errorMessage,
    this.warningMessage,
    required this.validatedValue,
  });
  
  /// Creates a successful validation result
  factory TareWeightValidationResult.success(double value, {String? warning}) {
    return TareWeightValidationResult(
      isValid: true,
      validatedValue: value,
      warningMessage: warning,
    );
  }
  
  /// Creates a failed validation result
  factory TareWeightValidationResult.error(String error, double fallbackValue) {
    return TareWeightValidationResult(
      isValid: false,
      errorMessage: error,
      validatedValue: fallbackValue,
    );
  }
  
  /// Returns true if there are any warnings
  bool get hasWarning => warningMessage != null && warningMessage!.isNotEmpty;
  
  /// Returns true if there are any errors
  bool get hasError => errorMessage != null && errorMessage!.isNotEmpty;
}