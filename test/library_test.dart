import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:source_shelf/library.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  group('Domain validation', () {
    test('blank source attributes throw', () {
      expect(
        () => Source(
          id: '',
          type: SourceType.book,
          title: 'Title',
          creators: ['Author'],
        ),
        throwsArgumentError,
      );
      expect(
        () => Source(
          id: 's1',
          type: SourceType.book,
          title: '   ',
          creators: ['Author'],
        ),
        throwsArgumentError,
      );
      expect(
        () => Source(
          id: 's1',
          type: SourceType.book,
          title: 'Title',
          creators: [''],
        ),
        throwsArgumentError,
      );
      expect(
        () => Source(
          id: 's1',
          type: SourceType.book,
          title: 'Title',
          creators: [],
          year: 0,
        ),
        throwsArgumentError,
      );
    });

    test('blank excerpt locators and invalid dates throw', () {
      expect(
        () => Excerpt(
          id: 'e1',
          sourceId: 's1',
          locator: ' ',
          quote: 'Quoted words',
          createdAt: '2026-10-30T00:00:00Z',
        ),
        throwsArgumentError,
      );
      expect(
        () => Excerpt(
          id: 'e1',
          sourceId: 's1',
          locator: 'p. 42',
          quote: '   ',
          createdAt: '2026-10-30T00:00:00Z',
        ),
        throwsArgumentError,
      );
      expect(
        () => Excerpt(
          id: 'e1',
          sourceId: 's1',
          locator: 'p. 42',
          quote: 'Quoted words',
          createdAt: 'not-a-date',
        ),
        throwsArgumentError,
      );
    });
  });

  group('SourceLibrary persistence', () {
    late SourceLibrary lib;

    setUp(() => lib = SourceLibrary.memory());
    tearDown(() => lib.dispose());

    test('CRUD for sources with creator order preserved', () {
      final s = Source(
        id: 'book-1',
        type: SourceType.book,
        title: 'The Design of Everyday Things',
        creators: ['Norman, Donald A.', 'Draper, Stephen W.'],
        year: 2013,
        publisher: 'Basic Books',
        identifier: '9780465050659',
      );
      lib.putSource(s);

      var list = lib.sources();
      expect(list.length, 1);
      expect(list.first.title, 'The Design of Everyday Things');
      expect(list.first.creators, ['Norman, Donald A.', 'Draper, Stephen W.']);
      expect(list.first.year, 2013);

      // Update
      lib.putSource(
        Source(
          id: 'book-1',
          type: SourceType.book,
          title: 'The Design of Everyday Things (Revised)',
          creators: ['Norman, Donald A.'],
          year: 2014,
        ),
      );
      list = lib.sources();
      expect(list.length, 1);
      expect(list.first.title, 'The Design of Everyday Things (Revised)');
      expect(list.first.creators, ['Norman, Donald A.']);

      lib.deleteSource('book-1');
      expect(lib.sources(), isEmpty);
    });

    test('excerpts link to source, maintain chronological order, and cascade delete', () {
      lib.putSource(
        Source(
          id: 's1',
          type: SourceType.article,
          title: 'As We May Think',
          creators: ['Bush, Vannevar'],
          year: 1945,
        ),
      );

      final e2 = Excerpt(
        id: 'e2',
        sourceId: 's1',
        locator: 'Section 6',
        quote: 'A memex is a device in which an individual stores all his books...',
        note: 'Core vision',
        createdAt: '2026-10-30T10:00:00Z',
      );
      final e1 = Excerpt(
        id: 'e1',
        sourceId: 's1',
        locator: 'Section 1',
        quote: 'The summation of human experience is being expanded at a prodigious rate.',
        createdAt: '2026-10-30T09:00:00Z',
      );

      lib.putExcerpt(e2);
      lib.putExcerpt(e1);

      final results = lib.excerpts('s1');
      expect(results.map((e) => e.id), ['e1', 'e2']);
      expect(results.first.locator, 'Section 1');

      // Cascade check
      lib.deleteSource('s1');
      expect(lib.excerpts('s1'), isEmpty);
    });

    test('excerpts reject non-existent source via foreign keys', () {
      expect(
        () => lib.putExcerpt(
          Excerpt(
            id: 'orphan',
            sourceId: 'missing',
            locator: 'p. 1',
            quote: 'text',
            createdAt: '2026-10-30T00:00:00Z',
          ),
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('search filters by prefix, tags, and collections', () {
      final s1 = Source(
        id: 's1',
        type: SourceType.book,
        title: 'Cognitive Engineering',
        creators: ['Norman, Donald'],
      );
      final s2 = Source(
        id: 's2',
        type: SourceType.book,
        title: 'Computer Lib',
        creators: ['Nelson, Ted'],
      );
      final s3 = Source(
        id: 's3',
        type: SourceType.article,
        title: 'Augmenting Human Intellect',
        creators: ['Engelbart, Douglas'],
      );

      lib.putSource(s1);
      lib.putSource(s2);
      lib.putSource(s3);

      lib.putCollection(Collection(id: 'c1', name: 'HCI History'));
      lib.addToCollection('s1', 'c1');
      lib.addToCollection('s3', 'c1');

      lib.addTag('s1', 'design');
      lib.addTag('s2', 'vision');

      expect(lib.sources(query: 'Comp').map((s) => s.id), ['s2']);
      expect(lib.sources(query: '%'), isEmpty);
      expect(lib.sources(query: '_'), isEmpty);
      expect(lib.sources(query: 'Comp', tag: 'design'), isEmpty);
      expect(
        lib
            .sources(query: 'Cogn', tag: 'design', collectionId: 'c1')
            .map((s) => s.id),
        ['s1'],
      );
      expect(lib.sources(collectionId: 'c1').map((s) => s.id), ['s3', 's1']);
      expect(lib.sources(tag: 'design').map((s) => s.id), ['s1']);
      expect(lib.tags('s1'), ['design']);

      lib.removeTag('s1', 'design');
      expect(lib.tags('s1'), isEmpty);
    });
  });

  group('Migration', () {
    test('migrates from v0 legacy database and preserves records', () {
      final tempDir = Directory.systemTemp.createTempSync('sourceshelf_mig_');
      final dbPath = '${tempDir.path}/legacy.sqlite';
      try {
        final raw = sqlite3.open(dbPath);
        raw.execute('''
          CREATE TABLE sources (
            id TEXT PRIMARY KEY, type TEXT NOT NULL, title TEXT NOT NULL,
            creators TEXT NOT NULL, year INTEGER, container TEXT,
            publisher TEXT, identifier TEXT
          );
        ''');
        raw.execute('''
          CREATE TABLE excerpts (
            id TEXT PRIMARY KEY, source_id TEXT NOT NULL REFERENCES sources(id) ON DELETE CASCADE,
            locator TEXT NOT NULL, quote TEXT NOT NULL, note TEXT NOT NULL,
            created_at TEXT NOT NULL
          );
        ''');
        raw.execute('''
          INSERT INTO sources VALUES ('leg-1', 'book', 'Old Book', '["Author, A."]', 1999, NULL, 'Old Press', NULL);
        ''');
        raw.execute('PRAGMA user_version = 0');
        raw.close();

        // Opening with SourceLibrary runs migration to v2
        final lib = SourceLibrary.openFile(dbPath);
        final version =
            lib.db.select('PRAGMA user_version').first.values.first as int;
        expect(version, 2);

        final sources = lib.sources();
        expect(sources.length, 1);
        expect(sources.first.id, 'leg-1');
        expect(sources.first.title, 'Old Book');

        // New collections/tags tables are accessible on migrated DB
        lib.putCollection(Collection(id: 'c-new', name: 'Migrated Shelf'));
        lib.addToCollection('leg-1', 'c-new');
        expect(lib.sources(collectionId: 'c-new').first.id, 'leg-1');

        lib.dispose();
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
