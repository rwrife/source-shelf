import 'dart:convert';

import 'citations.dart';
import 'library.dart';

/// Version 1 is a complete, user-owned snapshot. Import never trusts its contents.
String exportBackup(SourceLibrary library) {
  final sources = library.sources();
  return jsonEncode({
    'version': 1,
    'sources': [
      for (final s in sources)
        {
          'id': s.id,
          'type': s.type.name,
          'title': s.title,
          'creators': s.creators,
          'year': s.year,
          'container': s.container,
          'publisher': s.publisher,
          'identifier': s.identifier,
          'tags': library.tags(s.id),
          'collections': [
            for (final c in library.collections())
              if (library.sources(collectionId: c.id).any((v) => v.id == s.id))
                c.id,
          ],
        },
    ],
    'collections': [
      for (final c in library.collections()) {'id': c.id, 'name': c.name},
    ],
    'excerpts': [
      for (final s in sources)
        for (final e in library.excerpts(s.id))
          {
            'id': e.id,
            'sourceId': e.sourceId,
            'locator': e.locator,
            'quote': e.quote,
            'note': e.note,
            'createdAt': e.createdAt,
          },
    ],
  });
}

Map<String, dynamic> _object(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Expected object');
  }
  return value;
}

List<dynamic> _list(Object? value) {
  if (value is! List<dynamic>) throw const FormatException('Expected array');
  return value;
}

String _string(Object? value) {
  if (value is! String) throw const FormatException('Expected string');
  return value;
}

String? _optional(Object? value) => value == null ? null : _string(value);

void _fields(Map<String, dynamic> row, Set<String> expected) {
  if (row.keys.toSet().difference(expected).isNotEmpty ||
      expected.difference(row.keys.toSet()).isNotEmpty) {
    throw const FormatException('Missing or unknown backup fields');
  }
}

class _Backup {
  _Backup(this.sources, this.collections, this.excerpts, this.tags, this.links);
  final List<Source> sources;
  final List<Collection> collections;
  final List<Excerpt> excerpts;
  final Map<String, List<String>> tags;
  final Map<String, List<String>> links;
}

// Validate entire document, including relationships, before touching SQLite.
_Backup _parse(String input) {
  final root = _object(jsonDecode(input));
  _fields(root, {'version', 'sources', 'collections', 'excerpts'});
  if (root['version'] != 1) {
    throw const FormatException('Unsupported backup version');
  }
  final collections = <Collection>[];
  final collectionIds = <String>{};
  final collectionNames = <String>{};
  for (final value in _list(root['collections'])) {
    final row = _object(value);
    _fields(row, {'id', 'name'});
    final c = Collection(id: _string(row['id']), name: _string(row['name']));
    if (!collectionIds.add(c.id) ||
        !collectionNames.add(c.name.toLowerCase())) {
      throw const FormatException('Duplicate collection');
    }
    collections.add(c);
  }
  final sources = <Source>[];
  final ids = <String>{};
  final tags = <String, List<String>>{};
  final links = <String, List<String>>{};
  for (final value in _list(root['sources'])) {
    final row = _object(value);
    _fields(row, {
      'id',
      'type',
      'title',
      'creators',
      'year',
      'container',
      'publisher',
      'identifier',
      'tags',
      'collections',
    });
    final source = Source(
      id: _string(row['id']),
      type: SourceType.values.byName(_string(row['type'])),
      title: _string(row['title']),
      creators: _list(row['creators']).map(_string).toList(),
      year: row['year'] == null ? null : row['year'] as int,
      container: _optional(row['container']),
      publisher: _optional(row['publisher']),
      identifier: _optional(row['identifier']),
    );
    if (!ids.add(source.id)) throw const FormatException('Duplicate source ID');
    final sourceTags = _list(row['tags']).map(_string).toList();
    if (sourceTags.any((t) => t.trim().isEmpty) ||
        sourceTags.map((t) => t.toLowerCase()).toSet().length !=
            sourceTags.length) {
      throw const FormatException('Invalid or duplicate tags');
    }
    final sourceLinks = _list(row['collections']).map(_string).toList();
    if (sourceLinks.toSet().length != sourceLinks.length ||
        sourceLinks.any((id) => !collectionIds.contains(id))) {
      throw const FormatException('Invalid collection link');
    }
    tags[source.id] = sourceTags;
    links[source.id] = sourceLinks;
    sources.add(source);
  }
  final excerpts = <Excerpt>[];
  final excerptIds = <String>{};
  for (final value in _list(root['excerpts'])) {
    final row = _object(value);
    _fields(row, {'id', 'sourceId', 'locator', 'quote', 'note', 'createdAt'});
    final e = Excerpt(
      id: _string(row['id']),
      sourceId: _string(row['sourceId']),
      locator: _string(row['locator']),
      quote: _string(row['quote']),
      note: _string(row['note']),
      createdAt: _string(row['createdAt']),
    );
    if (!excerptIds.add(e.id) || !ids.contains(e.sourceId)) {
      throw const FormatException('Duplicate or orphan excerpt');
    }
    excerpts.add(e);
  }
  return _Backup(sources, collections, excerpts, tags, links);
}

/// Replace removes old rows; merge rejects ANY ID/name collision, never overwrites.
/// SQLite transaction protects previous data even if inserts fail midway.
void importBackup(SourceLibrary library, String json, {bool replace = false}) {
  final backup = _parse(json);
  final db = library.db;
  db.execute('BEGIN IMMEDIATE');
  try {
    if (replace) {
      db.execute('DELETE FROM sources');
      db.execute('DELETE FROM collections');
    } else {
      final existingSources = library.sources().map((s) => s.id).toSet();
      final existingCollections = library.collections();
      final existingExcerpts = db
          .select('SELECT id FROM excerpts')
          .map((r) => r['id'])
          .toSet();
      if (backup.sources.any((s) => existingSources.contains(s.id)) ||
          backup.collections.any(
            (c) => existingCollections.any(
              (old) =>
                  old.id == c.id ||
                  old.name.toLowerCase() == c.name.toLowerCase(),
            ),
          ) ||
          backup.excerpts.any((e) => existingExcerpts.contains(e.id))) {
        throw const FormatException(
          'ID or collection name collision; choose replace or review backup',
        );
      }
    }
    for (final c in backup.collections) {
      library.putCollection(c);
    }
    for (final s in backup.sources) {
      library.putSource(s);
      for (final tag in backup.tags[s.id]!) {
        library.addTag(s.id, tag);
      }
      for (final id in backup.links[s.id]!) {
        library.addToCollection(s.id, id);
      }
    }
    for (final e in backup.excerpts) {
      library.putExcerpt(e);
    }
    db.execute('COMMIT');
  } catch (_) {
    db.execute('ROLLBACK');
    rethrow;
  }
}

/// Quotes and notes may contain private material. UI must warn before sharing.
String exportMarkdown(SourceLibrary library) {
  final output = StringBuffer('# Source Shelf — private research export\n\n');
  for (final s in library.sources()) {
    output.writeln('## ${s.title.replaceAll('\n', ' ')}');
    final citation = apaReference(s);
    output.writeln(citation.text ?? '[Citation unavailable]');
    for (final warning in citation.warnings) {
      output.writeln('Warning: $warning');
    }
    for (final e in library.excerpts(s.id)) {
      if (s.type == SourceType.interview) {
        output.writeln(
          'Interview quote withheld: consent context not recorded.',
        );
        continue;
      }
      output.writeln(
        '\nLocator: ${e.locator}\n> ${e.quote.replaceAll('\n', '\n> ')}',
      );
      output.writeln('Note: ${e.note}\n');
    }
    output.writeln();
  }
  return output.toString();
}

String exportBibtex(SourceLibrary library) => library
    .sources()
    .map((s) {
      final draft = bibtex(s);
      return '${draft.warnings.map((w) => '% ${w.replaceAll('\n', ' ')}').join('\n')}\n${draft.text ?? '% Citation unavailable'}';
    })
    .join('\n\n');
