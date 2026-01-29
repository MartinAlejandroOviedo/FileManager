class SearchQuery {
  final List<String> nameTerms;
  final String? type;
  final String? ext;
  final int? minBytes;
  final int? maxBytes;
  final DateTime? minDate;
  final DateTime? maxDate;

  const SearchQuery({
    required this.nameTerms,
    this.type,
    this.ext,
    this.minBytes,
    this.maxBytes,
    this.minDate,
    this.maxDate,
  });
}

SearchQuery parseSearchQuery(String raw) {
  final tokens = raw
      .split(RegExp(r'\s+'))
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();

  String? type;
  String? ext;
  int? minBytes;
  int? maxBytes;
  DateTime? minDate;
  DateTime? maxDate;
  final nameTerms = <String>[];

  for (final token in tokens) {
    final lower = token.toLowerCase();
    if (lower.startsWith('type:')) {
      type = lower.substring(5);
      continue;
    }
    if (lower.startsWith('tipo:')) {
      type = lower.substring(5);
      continue;
    }
    if (lower.startsWith('ext:')) {
      ext = lower.substring(4).replaceFirst('.', '');
      continue;
    }
    if (lower.startsWith('size>') || lower.startsWith('tam>')) {
      minBytes = _parseSize(lower.split('>').last);
      continue;
    }
    if (lower.startsWith('size<') || lower.startsWith('tam<')) {
      maxBytes = _parseSize(lower.split('<').last);
      continue;
    }
    if (lower.startsWith('date>') || lower.startsWith('fecha>')) {
      minDate = _parseDate(lower.split('>').last);
      continue;
    }
    if (lower.startsWith('date<') || lower.startsWith('fecha<')) {
      maxDate = _parseDate(lower.split('<').last);
      continue;
    }
    nameTerms.add(lower);
  }

  return SearchQuery(
    nameTerms: nameTerms,
    type: type,
    ext: ext,
    minBytes: minBytes,
    maxBytes: maxBytes,
    minDate: minDate,
    maxDate: maxDate,
  );
}

int? _parseSize(String raw) {
  final match = RegExp(r'^(\d+(?:\.\d+)?)(kb|mb|gb|b)?$')
      .firstMatch(raw);
  if (match == null) return null;
  final value = double.tryParse(match.group(1) ?? '');
  if (value == null) return null;
  final unit = match.group(2) ?? 'b';
  switch (unit) {
    case 'kb':
      return (value * 1024).round();
    case 'mb':
      return (value * 1024 * 1024).round();
    case 'gb':
      return (value * 1024 * 1024 * 1024).round();
    default:
      return value.round();
  }
}

DateTime? _parseDate(String raw) {
  try {
    return DateTime.parse(raw);
  } catch (_) {
    return null;
  }
}
