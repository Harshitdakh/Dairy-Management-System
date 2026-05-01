/// Milk quantity utility — handles Liters + Milliliters format.
class MilkUtils {
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
