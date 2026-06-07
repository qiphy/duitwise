// lib/services/transaction_categorizer.dart

class TransactionCategorizer {
  // Central source of truth for keywords (supports English & Malay)
  static final Map<String, List<RegExp>> _categoryRules = {
    '🍿 Snacks & Food': [
      RegExp(r'\b(snack|food|makan|biscuit|candy|sweets|ice cream|aiskrim|coklat|chocolate|chips)\b'),
      RegExp(r'\b(canteen|kantin|mcd|kfc|starbucks|tealive|zus|boba|bakery|cafe)\b'),
    ],
    '🎮 Games & Entertainment': [
      RegExp(r'\b(game|gaming|steam|roblox|pubg|mobile legend|mlbb|nintendo|playstation|xbox)\b'),
      RegExp(r'\b(toy|mainan|comic|komik|movie|cinema|wayang|arcade|tokens)\b'),
    ],
    '📚 Education & School': [
      RegExp(r'\b(book|buku|stationery|alat tulis|pen|pencil|notebook|textbook|kamus)\b'),
      RegExp(r'\b(tuition|yuran|school|sekolah|class|seminar|exam|kertas)\b'),
    ],
    '🚌 Public Transport & Commute': [
      RegExp(r'\b(bus|bas|ktm|lrt|mrt|brt|drt|rapid|train|rail|tiket|ticket|fare)\b'),
      RegExp(r'\b(grab|taxi|teksi|touch n go|tng|reload)\b'),
    ],
    '🎁 Gifts & Sharing': [
      RegExp(r'\b(gift|hadiah|present|birthday|derma|charity|donation|sedekah|sharing)\b'),
    ],
  };

  /// Takes description text and determines its category systematically
  static String categorize(String description) {
    if (description.trim().isEmpty) return 'General';

    // Lowercase and strip out punctuation/emojis for robust matching
    final String cleanInput = description
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '') 
        .trim();

    for (final entry in _categoryRules.entries) {
      final String category = entry.key;
      final List<RegExp> expressions = entry.value;

      for (final regex in expressions) {
        if (regex.hasMatch(cleanInput)) {
          return category; 
        }
      }
    }

    return 'General'; // Fallback default
  }
}