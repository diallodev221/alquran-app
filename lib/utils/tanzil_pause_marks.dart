/// Pause marks (waqf) from Tanzil — like [tanzil.net](https://tanzil.net/docs/pause_marks).
///
/// When downloading from tanzil.net, check "Include pause marks" so the XML
/// contains these characters. They are then rendered in superscript like on Tanzil web.
library;

/// Unicode range for Arabic small high/low Quranic diacritics (pause marks, etc.).
/// U+06D6–U+06ED: Arabic Small High Ligature Sad, Qaf, Meem, Jeem, etc. (Medina Mushaf).
/// U+2234: ∴ THEREFORE (interchangeable pause).
bool isTanzilPauseMark(int codeUnit) {
  if (codeUnit >= 0x06D6 && codeUnit <= 0x06ED) return true;
  if (codeUnit == 0x2234) return true; // ∴
  return false;
}

/// Splits [text] into segments: normal text and pause mark characters.
/// Pause marks are single characters (or the pair ∴∴).
List<String> splitByPauseMarks(String text) {
  if (text.isEmpty) return [];
  final segments = <String>[];
  final runes = text.runes.toList();
  int i = 0;
  while (i < runes.length) {
    final r = runes[i];
    if (isTanzilPauseMark(r)) {
      segments.add(String.fromCharCode(r));
      i++;
    } else {
      final sb = StringBuffer();
      while (i < runes.length && !isTanzilPauseMark(runes[i])) {
        sb.writeCharCode(runes[i]);
        i++;
      }
      if (sb.isNotEmpty) segments.add(sb.toString());
    }
  }
  return segments;
}

/// Returns true if [segment] is a single pause mark (or the pair ∴∴).
bool segmentIsPauseMark(String segment) {
  if (segment.isEmpty) return false;
  final runes = segment.runes.toList();
  if (runes.length == 1) return isTanzilPauseMark(runes[0]);
  if (runes.length == 2 && runes[0] == 0x2234 && runes[1] == 0x2234) return true;
  return false;
}
