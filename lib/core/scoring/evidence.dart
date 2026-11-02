String _norm(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9%+#./ ]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

/// Checks a quote returned by the model against the words it was given: an exact substring, or at least 85% of its
/// words present in the source. Anything else is treated as invented and never backs a score.
bool quoteIsGrounded(String? quote, String source) {
  if (quote == null) return false;
  final n = _norm(quote);
  if (n.isEmpty) return false;
  final haystack = _norm(source);
  if (haystack.contains(n)) return true;
  final words = haystack.split(' ').toSet();
  final ws = n.split(' ');
  return ws.where(words.contains).length / ws.length >= 0.85;
}
