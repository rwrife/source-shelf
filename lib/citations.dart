import 'library.dart';

/// Drafts only. Metadata comes from user; missing fields stay visibly missing.
class CitationDraft {
  const CitationDraft(this.text, this.warnings);
  final String? text;
  final List<String> warnings;

  bool get canCopy => text != null && warnings.isEmpty;
}

String _present(String? value) => value?.trim() ?? '';

/// APA segments end in a period; do not double it after an initial like "A. A."
String _sentence(String value) => value.endsWith('.') ? value : '$value.';

String _authors(List<String> creators) {
  if (creators.isEmpty) return '';
  if (creators.length == 1) return creators.single.trim();
  return '${creators.take(creators.length - 1).map((c) => c.trim()).join(', ')}, & ${creators.last.trim()}';
}

/// APA 7 first-pass reference; names are printed exactly as entered, not guessed
/// into surnames/initials. User must proofread punctuation and creator order.
CitationDraft apaReference(Source source) {
  final warnings = <String>['Draft only: proofread against APA 7 before use.'];
  if (source.type == SourceType.interview) {
    return CitationDraft(null, [
      ...warnings,
      'Interview: consent and recoverability are unknown; do not publish a reference or private quote.',
    ]);
  }
  final creator = _authors(source.creators);
  if (creator.isEmpty)
    warnings.add('Missing creator; supply author or organization.');
  if (source.year == null)
    warnings.add(
      'Missing publication date; year-only format may be incomplete.',
    );
  final container = _present(source.container);
  final publisher = _present(source.publisher);
  final identifier = _present(source.identifier);
  if ((source.type == SourceType.article ||
          source.type == SourceType.chapter) &&
      container.isEmpty) {
    warnings.add('Missing journal or book title.');
  }
  if ((source.type == SourceType.book || source.type == SourceType.chapter) &&
      publisher.isEmpty) {
    warnings.add('Missing publisher.');
  }
  if (source.type == SourceType.article) {
    warnings.add(
      'Volume, issue and article page range not modeled; verify before use.',
    );
  }
  if (source.type == SourceType.chapter) {
    warnings.add(
      'Editors and chapter page range not modeled; verify before use.',
    );
  }
  if (source.type == SourceType.web && identifier.isEmpty) {
    warnings.add('Missing URL; identifier is not a verified URL.');
  }
  final start = [
    if (creator.isNotEmpty) _sentence(creator),
    '(${source.year ?? 'n.d.'}).',
    _sentence(source.title.trim()),
  ];
  final details = switch (source.type) {
    SourceType.book => [if (publisher.isNotEmpty) _sentence(publisher)],
    SourceType.article => [if (container.isNotEmpty) _sentence(container)],
    SourceType.chapter => [
      if (container.isNotEmpty) _sentence('In $container'),
      if (publisher.isNotEmpty) _sentence(publisher),
    ],
    SourceType.web => [if (container.isNotEmpty) _sentence(container)],
    SourceType.interview => <String>[],
  };
  return CitationDraft(
    [...start, ...details, if (identifier.isNotEmpty) identifier].join(' '),
    warnings,
  );
}

/// Citation of a verbatim excerpt. Locator printed verbatim; never infers page.
CitationDraft apaQuote(Source source, Excerpt excerpt) {
  final warnings = <String>['Draft only: proofread against APA 7 before use.'];
  if (excerpt.sourceId != source.id) {
    return CitationDraft(null, [
      ...warnings,
      'Excerpt does not belong to source.',
    ]);
  }
  if (source.type == SourceType.interview) {
    return CitationDraft(null, [
      ...warnings,
      'Interview consent and privacy not recorded; do not export quote.',
    ]);
  }
  final creator = _authors(source.creators);
  if (creator.isEmpty) warnings.add('Missing creator.');
  if (source.year == null) warnings.add('Missing publication date.');
  // ponytail: locator is literal user input; add structured page/section parsing
  // only when schema collects locator kind explicitly.
  return CitationDraft(
    '(${creator.isEmpty ? '[creator missing]' : creator}, ${source.year ?? 'n.d.'}, ${excerpt.locator.trim()})',
    warnings,
  );
}

String _bibEscape(String value) => value
    .replaceAll('\\', r'\textbackslash{}')
    .replaceAll('{', r'\{')
    .replaceAll('}', r'\}')
    .replaceAll('&', r'\&')
    .replaceAll('%', r'\%')
    .replaceAll(r'$', r'\$')
    .replaceAll('#', r'\#')
    .replaceAll('_', r'\_');

CitationDraft bibtex(Source source) {
  final warnings = <String>[
    'Draft only: check entry type and fields before use.',
  ];
  if (source.type == SourceType.interview) {
    return CitationDraft(null, [
      ...warnings,
      'Interview: consent unknown; BibTeX export unsupported.',
    ]);
  }
  final entry = switch (source.type) {
    SourceType.book => 'book',
    SourceType.article => 'article',
    SourceType.chapter => 'incollection',
    SourceType.web => 'misc',
    SourceType.interview => 'misc',
  };
  final key = source.id.replaceAll(RegExp(r'[^A-Za-z0-9:_-]'), '_');
  if (source.creators.isEmpty) warnings.add('Missing author.');
  if (source.year == null) warnings.add('Missing year.');
  if ((source.type == SourceType.article ||
          source.type == SourceType.chapter) &&
      _present(source.container).isEmpty) {
    warnings.add('Missing journal or booktitle.');
  }
  if ((source.type == SourceType.book || source.type == SourceType.chapter) &&
      _present(source.publisher).isEmpty) {
    warnings.add('Missing publisher.');
  }
  if (source.type == SourceType.article)
    warnings.add('Volume, issue and pages not modeled.');
  if (source.type == SourceType.chapter)
    warnings.add('Editors and pages not modeled.');
  final fields = <String, String>{
    if (source.creators.isNotEmpty)
      'author': source.creators.map((c) => c.trim()).join(' and '),
    'title': source.title.trim(),
    if (source.year != null) 'year': '${source.year}',
    if (_present(source.container).isNotEmpty)
      (switch (source.type) {
        SourceType.article => 'journal',
        SourceType.chapter => 'booktitle',
        _ => 'howpublished',
      }): source.container!
          .trim(),
    if (_present(source.publisher).isNotEmpty)
      'publisher': source.publisher!.trim(),
    if (_present(source.identifier).isNotEmpty)
      'note': source.identifier!.trim(),
  };
  final lines = fields.entries
      .map((field) => '  ${field.key} = {${_bibEscape(field.value)}}')
      .join(',\n');
  return CitationDraft('@$entry{$key,\n$lines\n}', warnings);
}
