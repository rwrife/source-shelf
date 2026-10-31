import 'package:flutter_test/flutter_test.dart';
import 'package:source_shelf/citations.dart';
import 'package:source_shelf/library.dart';

void main() {
  Source source(
    SourceType type, {
    List<String> creators = const ['Smith, J.'],
    int? year = 2020,
    String? container,
    String? publisher,
    String? identifier,
  }) => Source(
    id: 'smith-2020',
    type: type,
    title: 'Research methods',
    creators: creators,
    year: year,
    container: container,
    publisher: publisher,
    identifier: identifier,
  );

  test('book reference keeps user-entered initials; no doubled period', () {
    final draft = apaReference(
      source(SourceType.book, publisher: 'Acme Press'),
    );
    expect(draft.text, 'Smith, J. (2020). Research methods. Acme Press.');
    expect(draft.warnings, contains(contains('proofread')));
  });

  test('book draft does not invent missing creator, year, publisher', () {
    final draft = apaReference(
      source(SourceType.book, creators: [], year: null),
    );
    expect(draft.text, '(n.d.). Research methods.');
    expect(draft.warnings.join(' '), contains('Missing creator'));
    expect(draft.warnings.join(' '), contains('Missing publication date'));
    expect(draft.warnings.join(' '), contains('Missing publisher'));
    expect(draft.canCopy, isFalse);
  });

  test('article and chapter flag unmodeled APA 7 fields', () {
    final article = apaReference(
      source(SourceType.article, container: 'Journal of Examples'),
    );
    expect(article.text, contains('Journal of Examples.'));
    expect(article.warnings.join(' '), contains('Volume, issue'));
    final chapter = apaReference(
      source(
        SourceType.chapter,
        container: 'Methods Handbook',
        publisher: 'Acme',
      ),
    );
    expect(chapter.text, contains('In Methods Handbook. Acme.'));
    expect(
      chapter.warnings.join(' '),
      contains('Editors and chapter page range'),
    );
  });

  test('web source requires a user-entered URL; never claims verification', () {
    final draft = apaReference(
      source(SourceType.web, identifier: 'https://example.org/page'),
    );
    expect(draft.text, endsWith('https://example.org/page'));
    expect(draft.text, isNot(contains('Retrieved')));
    expect(
      apaReference(source(SourceType.web)).warnings.join(' '),
      contains('Missing URL'),
    );
  });

  test('verbatim locator and source mismatch', () {
    final src = source(SourceType.book);
    final quote = Excerpt(
      id: 'e',
      sourceId: src.id,
      locator: '§ 3.2, p. 44',
      quote: 'exact',
      createdAt: '2026-10-31',
    );
    expect(apaQuote(src, quote).text, '(Smith, J., 2020, § 3.2, p. 44)');
    final other = Source(
      id: 'other',
      type: SourceType.web,
      title: 'Other page',
      creators: const ['Smith, J.'],
    );
    expect(apaQuote(other, quote).text, isNull);
  });

  test('private interview has no reference or exportable quote', () {
    final src = source(SourceType.interview);
    final quote = Excerpt(
      id: 'e',
      sourceId: src.id,
      locator: 'timestamp 00:42',
      quote: 'private',
      createdAt: '2026-10-31',
    );
    expect(apaReference(src).text, isNull);
    expect(apaQuote(src, quote).text, isNull);
    expect(bibtex(src).text, isNull);
  });

  test(
    'BibTeX escapes special characters, keeps ordered authors and exact ID',
    () {
      final draft = bibtex(
        source(
          SourceType.book,
          creators: ['Smith, J.', 'Doe, A.'],
          publisher: 'A&B {Press}',
          identifier: r'ISBN 100%_#$',
        ),
      );
      expect(draft.text, startsWith('@book{smith-2020,\n'));
      expect(draft.text, contains('author = {Smith, J. and Doe, A.}'));
      expect(draft.text, contains(r'publisher = {A\&B \{Press\}}'));
      expect(draft.text, contains(r'note = {ISBN 100\%\_\#\$}'));
      expect(draft.text, isNot(contains('doi =')));
    },
  );

  test('BibTeX article and chapter types and missing-field warnings', () {
    expect(bibtex(source(SourceType.article)).text, startsWith('@article{'));
    expect(
      bibtex(source(SourceType.article)).warnings.join(' '),
      contains('Missing journal'),
    );
    expect(
      bibtex(source(SourceType.chapter)).text,
      startsWith('@incollection{'),
    );
    expect(
      bibtex(source(SourceType.chapter)).warnings.join(' '),
      contains('Editors and pages'),
    );
  });
}
