import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

/// Metadata and locators are user-entered; nothing is inferred or fetched.
enum SourceType { book, article, chapter, web, interview }

class Source {
  Source({
    required this.id,
    required this.type,
    required this.title,
    required this.creators,
    this.year,
    this.container,
    this.publisher,
    this.identifier,
  }) {
    _require(id, 'Source ID');
    _require(title, 'Title');
    if (creators.any((name) => name.trim().isEmpty)) {
      throw ArgumentError('Creators cannot be blank');
    }
    if (year != null && (year! < 1 || year! > 9999)) {
      throw ArgumentError('Invalid publication year');
    }
  }

  final String id;
  final SourceType type;
  final String title;
  final List<String> creators;
  final int? year;
  final String? container;
  final String? publisher;
  final String? identifier;
}

class Excerpt {
  Excerpt({
    required this.id,
    required this.sourceId,
    required this.locator,
    required this.quote,
    required this.createdAt,
    this.note = '',
  }) {
    _require(id, 'Excerpt ID');
    _require(sourceId, 'Source ID');
    _require(locator, 'Exact page or section locator');
    _require(quote, 'Quote');
    if (DateTime.tryParse(createdAt) == null) {
      throw ArgumentError('Invalid capture date');
    }
  }

  final String id;
  final String sourceId;
  final String locator;
  final String quote;
  final String note;
  final String createdAt;
}

class Collection {
  Collection({required this.id, required this.name}) {
    _require(id, 'Collection ID');
    _require(name, 'Collection name');
  }

  final String id;
  final String name;
}

void _require(String value, String field) {
  if (value.trim().isEmpty) throw ArgumentError('$field cannot be blank');
}

/// Caller owns lifecycle. DB file remains local to app support directory.
class SourceLibrary {
  SourceLibrary._(this.db) {
    db.execute('PRAGMA foreign_keys = ON');
    final version = db.select('PRAGMA user_version').first.values.first as int;
    if (version > 2) throw StateError('Library created by newer app');
    db.execute('BEGIN IMMEDIATE');
    try {
      if (version == 0) {
        db.execute('''
          CREATE TABLE IF NOT EXISTS sources (
            id TEXT PRIMARY KEY, type TEXT NOT NULL, title TEXT NOT NULL,
            creators TEXT NOT NULL, year INTEGER, container TEXT,
            publisher TEXT, identifier TEXT
          )
        ''');
        db.execute('''
          CREATE TABLE IF NOT EXISTS excerpts (
            id TEXT PRIMARY KEY, source_id TEXT NOT NULL REFERENCES sources(id) ON DELETE CASCADE,
            locator TEXT NOT NULL, quote TEXT NOT NULL, note TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
      }
      if (version < 2) {
        db.execute(
          'CREATE INDEX IF NOT EXISTS sources_title ON sources(title COLLATE NOCASE)',
        );
        db.execute(
          'CREATE INDEX IF NOT EXISTS excerpts_source_order ON excerpts(source_id, created_at, id)',
        );
        db.execute(
          'CREATE TABLE IF NOT EXISTS collections (id TEXT PRIMARY KEY, name TEXT NOT NULL UNIQUE COLLATE NOCASE)',
        );
        db.execute('''
          CREATE TABLE IF NOT EXISTS source_collections (
            source_id TEXT NOT NULL REFERENCES sources(id) ON DELETE CASCADE,
            collection_id TEXT NOT NULL REFERENCES collections(id) ON DELETE CASCADE,
            PRIMARY KEY (source_id, collection_id)
          )
        ''');
        db.execute(
          'CREATE INDEX IF NOT EXISTS source_collections_collection ON source_collections(collection_id, source_id)',
        );
        db.execute('''
          CREATE TABLE IF NOT EXISTS source_tags (
            source_id TEXT NOT NULL REFERENCES sources(id) ON DELETE CASCADE,
            tag TEXT NOT NULL COLLATE NOCASE,
            PRIMARY KEY (source_id, tag)
          )
        ''');
        db.execute(
          'CREATE INDEX IF NOT EXISTS source_tags_tag ON source_tags(tag, source_id)',
        );
        db.execute('PRAGMA user_version = 2');
      }
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  final Database db;

  static SourceLibrary memory() => SourceLibrary._(sqlite3.openInMemory());

  static Future<SourceLibrary> open() async {
    final directory = await getApplicationSupportDirectory();
    await Directory(directory.path).create(recursive: true);
    return SourceLibrary._(
      sqlite3.open(path.join(directory.path, 'sources.sqlite')),
    );
  }

  static SourceLibrary openFile(String filename) =>
      SourceLibrary._(sqlite3.open(filename));

  void dispose() => db.close();

  void putSource(Source source) {
    db.execute(
      '''
      INSERT INTO sources (id, type, title, creators, year, container, publisher, identifier)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET type=excluded.type, title=excluded.title,
        creators=excluded.creators, year=excluded.year, container=excluded.container,
        publisher=excluded.publisher, identifier=excluded.identifier
    ''',
      [
        source.id, source.type.name, source.title,
        // JSON preserves creator order and punctuation without custom delimiters.
        _encodeCreators(source.creators), source.year, source.container,
        source.publisher, source.identifier,
      ],
    );
  }

  List<Source> sources({String query = '', String? tag, String? collectionId}) {
    final sql = StringBuffer('SELECT s.* FROM sources s WHERE 1=1');
    final args = <Object?>[];
    if (query.isNotEmpty) {
      // ponytail: indexed prefix title search; add FTS when substring/quote search needed.
      sql.write(" AND s.title LIKE ? ESCAPE '\\'");
      args.add('${_escapeLike(query)}%');
    }
    if (tag != null) {
      sql.write(
        ' AND EXISTS (SELECT 1 FROM source_tags t WHERE t.source_id=s.id AND t.tag=?)',
      );
      args.add(tag);
    }
    if (collectionId != null) {
      sql.write(
        ' AND EXISTS (SELECT 1 FROM source_collections c WHERE c.source_id=s.id AND c.collection_id=?)',
      );
      args.add(collectionId);
    }
    sql.write(' ORDER BY s.title COLLATE NOCASE, s.id');
    return db
        .select(sql.toString(), args)
        .map(
          (row) => Source(
            id: row['id'] as String,
            type: SourceType.values.byName(row['type'] as String),
            title: row['title'] as String,
            creators: _decodeCreators(row['creators'] as String),
            year: row['year'] as int?,
            container: row['container'] as String?,
            publisher: row['publisher'] as String?,
            identifier: row['identifier'] as String?,
          ),
        )
        .toList();
  }

  void deleteSource(String id) =>
      db.execute('DELETE FROM sources WHERE id=?', [id]);

  void putExcerpt(Excerpt excerpt) => db.execute(
    '''
    INSERT INTO excerpts (id, source_id, locator, quote, note, created_at)
    VALUES (?, ?, ?, ?, ?, ?)
    ON CONFLICT(id) DO UPDATE SET source_id=excluded.source_id,
      locator=excluded.locator, quote=excluded.quote, note=excluded.note,
      created_at=excluded.created_at
  ''',
    [
      excerpt.id,
      excerpt.sourceId,
      excerpt.locator,
      excerpt.quote,
      excerpt.note,
      excerpt.createdAt,
    ],
  );

  List<Excerpt> excerpts(String sourceId) => db
      .select(
        '''
    SELECT * FROM excerpts WHERE source_id=? ORDER BY created_at, id
  ''',
        [sourceId],
      )
      .map(
        (row) => Excerpt(
          id: row['id'] as String,
          sourceId: row['source_id'] as String,
          locator: row['locator'] as String,
          quote: row['quote'] as String,
          note: row['note'] as String,
          createdAt: row['created_at'] as String,
        ),
      )
      .toList();

  void deleteExcerpt(String id) =>
      db.execute('DELETE FROM excerpts WHERE id=?', [id]);

  void putCollection(Collection collection) => db.execute(
    '''
    INSERT INTO collections (id, name) VALUES (?, ?)
    ON CONFLICT(id) DO UPDATE SET name=excluded.name
  ''',
    [collection.id, collection.name],
  );

  List<Collection> collections() => db
      .select('SELECT * FROM collections ORDER BY name COLLATE NOCASE, id')
      .map(
        (row) =>
            Collection(id: row['id'] as String, name: row['name'] as String),
      )
      .toList();

  void deleteCollection(String id) =>
      db.execute('DELETE FROM collections WHERE id=?', [id]);

  void addToCollection(String sourceId, String collectionId) => db.execute(
    '''
    INSERT OR IGNORE INTO source_collections (source_id, collection_id) VALUES (?, ?)
  ''',
    [sourceId, collectionId],
  );

  void removeFromCollection(String sourceId, String collectionId) => db.execute(
    '''
    DELETE FROM source_collections WHERE source_id=? AND collection_id=?
  ''',
    [sourceId, collectionId],
  );

  void addTag(String sourceId, String tag) {
    _require(tag, 'Tag');
    db.execute(
      'INSERT OR IGNORE INTO source_tags (source_id, tag) VALUES (?, ?)',
      [sourceId, tag.trim()],
    );
  }

  void removeTag(String sourceId, String tag) => db.execute(
    'DELETE FROM source_tags WHERE source_id=? AND tag=?',
    [sourceId, tag],
  );

  List<String> tags(String sourceId) => db
      .select(
        'SELECT tag FROM source_tags WHERE source_id=? ORDER BY tag COLLATE NOCASE',
        [sourceId],
      )
      .map((row) => row['tag'] as String)
      .toList();
}

// dart:convert is used only for ordered creator strings; no remote metadata.
String _encodeCreators(List<String> creators) => jsonEncode(creators);
List<String> _decodeCreators(String value) =>
    (jsonDecode(value) as List).cast<String>();
String _escapeLike(String input) => input
    .replaceAll('\\', '\\\\')
    .replaceAll('%', '\\%')
    .replaceAll('_', '\\_');
