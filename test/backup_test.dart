import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:source_shelf/backup.dart';
import 'package:source_shelf/library.dart';

void main() {
  late SourceLibrary library;
  setUp(() => library = SourceLibrary.memory());
  tearDown(() => library.dispose());

  void seed() {
    library.putSource(
      Source(
        id: 's',
        type: SourceType.book,
        title: 'T',
        creators: ['A'],
        year: 2020,
      ),
    );
    library.putCollection(Collection(id: 'c', name: 'Research'));
    library.addToCollection('s', 'c');
    library.addTag('s', 'critical');
    library.putExcerpt(
      Excerpt(
        id: 'e',
        sourceId: 's',
        locator: 'p. 9',
        quote: 'Exact words',
        note: 'private note',
        createdAt: '2025-01-01T00:00:00Z',
      ),
    );
  }

  test('round trip replace preserves every row and exact locator', () {
    seed();
    final backup = exportBackup(library);
    final other = SourceLibrary.memory();
    try {
      other.putSource(
        Source(id: 'old', type: SourceType.web, title: 'Old', creators: []),
      );
      importBackup(other, backup, replace: true);
      expect(exportBackup(other), backup);
      expect(other.sources().single.id, 's');
      expect(other.excerpts('s').single.locator, 'p. 9');

      // Non-colliding merge adds new rows without wiping old
      final nonColliding = jsonEncode({
        'version': 1,
        'sources': [
          {
            'id': 's2',
            'type': 'web',
            'title': 'Online Doc',
            'creators': ['Zed'],
            'year': 2024,
            'container': null,
            'publisher': null,
            'identifier': 'https://example.com',
            'tags': ['web'],
            'collections': ['c2'],
          },
        ],
        'collections': [
          {'id': 'c2', 'name': 'Web Articles'},
        ],
        'excerpts': [
          {
            'id': 'e2',
            'sourceId': 's2',
            'locator': 'sec 4',
            'quote': 'Web quote',
            'note': '',
            'createdAt': '2025-02-01T00:00:00Z',
          },
        ],
      });
      importBackup(other, nonColliding, replace: false);
      expect(other.sources().length, 2);
      expect(other.collections().length, 2);
      expect(other.excerpts('s2').single.locator, 'sec 4');
    } finally {
      other.dispose();
    }
  });

  test(
    'preflight rejects corrupt data and merge collisions without mutation',
    () {
      seed();
      final snapshot = exportBackup(library);
      final data = jsonDecode(snapshot) as Map<String, dynamic>;
      (data['excerpts'] as List).first['sourceId'] = 'missing';
      expect(
        () => importBackup(library, jsonEncode(data), replace: true),
        throwsFormatException,
      );
      expect(() => importBackup(library, snapshot), throwsFormatException);
      expect(() => importBackup(library, '{'), throwsFormatException);
      data['version'] = 2;
      expect(
        () => importBackup(library, jsonEncode(data)),
        throwsFormatException,
      );
      data['version'] = 1;
      (data['sources'] as List).first['secret'] = 'unexpected';
      expect(
        () => importBackup(library, jsonEncode(data)),
        throwsFormatException,
      );
      expect(exportBackup(library), snapshot);
    },
  );

  test('transaction rolls back even when database constraint fails after inserts', () {
    seed();
    final snapshot = exportBackup(library);
    // Force failure after DELETE and before COMMIT; transaction restores rows.
    library.db.execute('''
        CREATE TRIGGER block_backup BEFORE INSERT ON sources
        BEGIN SELECT RAISE(ABORT, 'write failure'); END
      ''');
    expect(
      () => importBackup(library, snapshot, replace: true),
      throwsException,
    );
    expect(exportBackup(library), snapshot);
  });

  test(
    'exports warn, withhold interview quotes and preserve literal page locator',
    () {
      seed();
      library.putSource(
        Source(
          id: 'i',
          type: SourceType.interview,
          title: 'Interview',
          creators: ['R'],
        ),
      );
      library.putExcerpt(
        Excerpt(
          id: 'ie',
          sourceId: 'i',
          locator: 'time 12:30',
          quote: 'Do not publish',
          createdAt: '2025-01-01',
        ),
      );
      final markdown = exportMarkdown(library);
      expect(markdown, contains('p. 9'));
      expect(markdown, contains('private note'));
      expect(markdown, contains('Interview quote withheld'));
      expect(markdown, isNot(contains('Do not publish')));
      final bib = exportBibtex(library);
      expect(bib, contains('@book{s,'));
      expect(bib, isNot(contains('@misc{i,')));
    },
  );
}
