String formatPaise(int paise) {
  final isNegative = paise < 0;
  final absolute = paise.abs();
  final rupees = absolute ~/ 100;
  final fractional = (absolute % 100).toString().padLeft(2, '0');
  return '${isNegative ? '-' : ''}Rs. $rupees.$fractional';
}

int? parseRupeesToPaise(String input) {
  final normalized = input.trim();
  if (normalized.isEmpty) {
    return null;
  }

  final rupees = double.tryParse(normalized);
  if (rupees == null || rupees < 0) {
    return null;
  }

  return (rupees * 100).round();
}

String formatPaiseAsEditableRupees(int paise) {
  return (paise / 100).toStringAsFixed(2);
}
