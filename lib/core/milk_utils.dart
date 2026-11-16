/// Milk quantity utility — handles Liters + Milliliters format and Devanagari digit conversion.
class MilkUtils {
  /// Devanagari numeral characters (`०, १, २, ३, ४, ५, ६, ७, ८, ९`).
  static const List<String> devanagariDigits = [
    '०', '१', '२', '३', '४', '५', '६', '७', '८', '९',
  ];

  /// Standard ASCII digit characters (`0, 1, 2, 3, 4, 5, 6, 7, 8, 9`).
  static const List<String> asciiDigits = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
  ];

  /// Convert ASCII digits in a string to Hindi Devanagari numerals.
  static String toDevanagariDigits(String input) {
    String res = input;
    for (int i = 0; i < 10; i++) {
      res = res.replaceAll(asciiDigits[i], devanagariDigits[i]);
    }
    return res;
  }

  /// Convert Hindi Devanagari numerals in a string to standard ASCII digits.
  static String fromDevanagariDigits(String input) {
    String res = input;
    for (int i = 0; i < 10; i++) {
      res = res.replaceAll(devanagariDigits[i], asciiDigits[i]);
    }
    return res;
  }

  /// Try parse integer supporting both ASCII and Devanagari numerals.
  static int? tryParseInt(String input) {
    return int.tryParse(fromDevanagariDigits(input.trim()));
  }

  /// Try parse double supporting both ASCII and Devanagari numerals.
  static double? tryParseDouble(String input) {
    return double.tryParse(fromDevanagariDigits(input.trim()));
  }

  /// Convert liters + ml to a single decimal value.
  static double toDecimal(num liters, num ml) {
    return liters.toDouble() + (ml.toDouble() / 1000);
  }

  /// Convert a decimal total liters back to (liters, ml) tuple.
  static ({int liters, int ml}) fromDecimal(double totalLiters) {
    final liters = totalLiters.truncate();
    final ml = ((totalLiters - liters) * 1000).round();
    return (liters: liters, ml: ml);
  }

  /// Format a quantity for display: "50 L 500 ml" or "50 L" if no ml.
  static String formatQuantity(num liters, num ml) {
    if (ml > 0) {
      return '${liters.toInt()} L ${ml.toInt()} ml';
    }
    return '${liters.toInt()} L';
  }

  /// Calculate the total amount based on quantity and rate.
  static double calculateAmount(num liters, num ml, num rate) {
    final totalLiters = toDecimal(liters, ml);
    return totalLiters * rate.toDouble();
  }
}
