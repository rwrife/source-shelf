import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'backup.dart';
import 'citations.dart';
import 'library.dart';

// Backups and quote exports contain private research; never share implicitly.
const _exportWarning =
    'Files and clipboard text can contain private research notes and verbatim quotes. Review before sharing.';

/// UI stays local: no metadata lookup, network request, or generated locator.
class Catalog extends StatefulWidget {
  const Catalog({super.key, required this.platform, this.library});

  final TargetPlatform platform;
  final SourceLibrary? library;

  @override
  State<Catalog> createState() => _CatalogState();
}

class _CatalogState extends State<Catalog> {
  SourceLibrary? library;
  String query = '';
  String? collectionId;
  Source? selected;
  String? error;

  @override
  void initState() {
    super.initState();
    library = widget.library;
    if (library == null) {
      SourceLibrary.open()
          .then((value) {
            if (!mounted) {
              value.dispose();
            } else {
              setState(() => library = value);
            }
          })
          .catchError((Object failure) {
            if (mounted) {
              setState(() => error = 'Unable to open local library: $failure');
            }
          });
    }
  }

  @override
  void dispose() {
    if (widget.library == null) library?.dispose();
    super.dispose();
  }

  Future<void> editSource([Source? existing]) async {
    final title = TextEditingController(text: existing?.title ?? '');
    final creators = TextEditingController(
      text: existing?.creators.join('; ') ?? '',
    );
    final year = TextEditingController(text: existing?.year?.toString() ?? '');
    final container = TextEditingController(text: existing?.container ?? '');
    final publisher = TextEditingController(text: existing?.publisher ?? '');
    final identifier = TextEditingController(text: existing?.identifier ?? '');
    final tag = TextEditingController(
      text: existing == null ? '' : library!.tags(existing.id).join(', '),
    );
    var type = existing?.type ?? SourceType.book;
    String? validation;
    final result = await showDialogForPlatform<Source>(
      context,
      widget.platform,
      (close) => StatefulBuilder(
        builder: (context, update) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              existing == null ? 'New source' : 'Edit source',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 12),
            Text('Type: ${type.name}'),
            Wrap(
              children: SourceType.values
                  .map(
                    (option) => Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: PlatformButton(
                        platform: widget.platform,
                        label: option.name,
                        onPressed: () => update(() => type = option),
                      ),
                    ),
                  )
                  .toList(),
            ),
            PlatformField(
              platform: widget.platform,
              label: 'Title',
              controller: title,
            ),
            PlatformField(
              platform: widget.platform,
              label: 'Creators (separate with ;)',
              controller: creators,
            ),
            PlatformField(
              platform: widget.platform,
              label: 'Publication year (optional)',
              controller: year,
              keyboardType: TextInputType.number,
            ),
            PlatformField(
              platform: widget.platform,
              label: 'Container (optional)',
              controller: container,
            ),
            PlatformField(
              platform: widget.platform,
              label: 'Publisher (optional)',
              controller: publisher,
            ),
            PlatformField(
              platform: widget.platform,
              label: 'Identifier (optional)',
              controller: identifier,
            ),
            PlatformField(
              platform: widget.platform,
              label: 'Tags (separate with ,)',
              controller: tag,
            ),
            if (validation != null)
              Text(
                validation!,
                style: const TextStyle(color: Color(0xffa32424)),
              ),
            Wrap(
              alignment: WrapAlignment.end,
              children: [
                PlatformButton(
                  platform: widget.platform,
                  label: 'Cancel',
                  onPressed: () => close(),
                ),
                PlatformButton(
                  platform: widget.platform,
                  label: 'Save source',
                  onPressed: () {
                    try {
                      final enteredYear = year.text.trim();
                      final value = Source(
                        id:
                            existing?.id ??
                            DateTime.now().microsecondsSinceEpoch.toString(),
                        type: type,
                        title: title.text.trim(),
                        creators: creators.text
                            .split(';')
                            .map((s) => s.trim())
                            .toList(),
                        year: enteredYear.isEmpty
                            ? null
                            : int.parse(enteredYear),
                        container: container.text.trim().isEmpty
                            ? null
                            : container.text.trim(),
                        publisher: publisher.text.trim().isEmpty
                            ? null
                            : publisher.text.trim(),
                        identifier: identifier.text.trim().isEmpty
                            ? null
                            : identifier.text.trim(),
                      );
                      library!.putSource(value);
                      for (final old in library!.tags(value.id)) {
                        library!.removeTag(value.id, old);
                      }
                      for (final label
                          in tag.text
                              .split(',')
                              .map((s) => s.trim())
                              .where((s) => s.isNotEmpty)) {
                        library!.addTag(value.id, label);
                      }
                      close(value);
                    } catch (failure) {
                      update(
                        () => validation =
                            'Check required title, creators and year: $failure',
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
    // ponytail: temporary form controllers are GC'd after route exit; extract a form State for explicit disposal if forms grow.
    if (result != null && mounted) setState(() => selected = result);
  }

  Future<void> addExcerpt(Source source) async {
    final locator = TextEditingController();
    final quote = TextEditingController();
    final note = TextEditingController();
    String? validation;
    final added = await showDialogForPlatform<bool>(
      context,
      widget.platform,
      (close) => StatefulBuilder(
        builder: (context, update) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Capture excerpt', style: TextStyle(fontSize: 20)),
            PlatformField(
              platform: widget.platform,
              label: 'Exact page or section locator',
              controller: locator,
            ),
            PlatformField(
              platform: widget.platform,
              label: 'Verbatim quote',
              controller: quote,
              maxLines: 3,
            ),
            PlatformField(
              platform: widget.platform,
              label: 'Your note (optional)',
              controller: note,
              maxLines: 2,
            ),
            if (validation != null)
              Text(
                validation!,
                style: const TextStyle(color: Color(0xffa32424)),
              ),
            Wrap(
              alignment: WrapAlignment.end,
              children: [
                PlatformButton(
                  platform: widget.platform,
                  label: 'Cancel',
                  onPressed: () => close(),
                ),
                PlatformButton(
                  platform: widget.platform,
                  label: 'Save excerpt',
                  onPressed: () {
                    try {
                      final value = Excerpt(
                        id: DateTime.now().microsecondsSinceEpoch.toString(),
                        sourceId: source.id,
                        locator: locator.text.trim(),
                        quote: quote.text.trim(),
                        note: note.text.trim(),
                        createdAt: DateTime.now().toUtc().toIso8601String(),
                      );
                      library!.putExcerpt(value);
                      close(true);
                    } catch (failure) {
                      update(
                        () => validation =
                            'Enter exact locator and quote: $failure',
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
    // ponytail: temporary controllers are GC'd after route exit; extract State for explicit disposal if forms grow.
    if (added == true && mounted) setState(() {});
  }

  Future<void> addCollection() async {
    final name = TextEditingController();
    String? validation;
    final added = await showDialogForPlatform<bool>(
      context,
      widget.platform,
      (close) => StatefulBuilder(
        builder: (context, update) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('New collection', style: TextStyle(fontSize: 20)),
            PlatformField(
              platform: widget.platform,
              label: 'Collection name',
              controller: name,
            ),
            if (validation != null)
              Text(
                validation!,
                style: const TextStyle(color: Color(0xffa32424)),
              ),
            PlatformButton(
              platform: widget.platform,
              label: 'Save collection',
              onPressed: () {
                try {
                  library!.putCollection(
                    Collection(
                      id: DateTime.now().microsecondsSinceEpoch.toString(),
                      name: name.text.trim(),
                    ),
                  );
                  close(true);
                } catch (failure) {
                  update(
                    () => validation = 'Enter unique collection name: $failure',
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
    if (added == true && mounted) setState(() {});
  }

  Future<void> saveExport(String kind) async {
    final ok = await showDialogForPlatform<bool>(
      context,
      widget.platform,
      (close) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(_exportWarning),
          PlatformButton(
            platform: widget.platform,
            label: 'Cancel',
            onPressed: () => close(false),
          ),
          PlatformButton(
            platform: widget.platform,
            label: 'Continue',
            onPressed: () => close(true),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final content = switch (kind) {
        'json' => exportBackup(library!),
        'md' => exportMarkdown(library!),
        'bib' => exportBibtex(library!),
        _ => throw ArgumentError.value(kind),
      };
      await FilePicker.saveFile(
        dialogTitle: 'Save Source Shelf export',
        fileName: 'source-shelf.$kind',
        mimeType: kind == 'json' ? 'application/json' : 'text/plain',
        bytes: utf8.encode(content),
      );
      if (mounted) setState(() => error = null);
    } catch (failure) {
      if (mounted) setState(() => error = 'Export failed: $failure');
    }
  }

  Future<void> importFile() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (file == null || !mounted) return;
      final contents = utf8.decode(await file.readAsBytes());
      if (!mounted) return;
      // Preflight before offering destructive replacement.
      final preview = SourceLibrary.memory();
      try {
        importBackup(preview, contents, replace: true);
      } finally {
        preview.dispose();
      }
      if (!mounted) return;
      final replace = await showDialogForPlatform<bool>(
        context,
        widget.platform,
        (close) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Import backup? Merge rejects ID/name collisions. Replace deletes current library after validation. Keep a backup first.',
            ),
            PlatformButton(
              platform: widget.platform,
              label: 'Cancel',
              onPressed: () => close(),
            ),
            PlatformButton(
              platform: widget.platform,
              label: 'Merge',
              onPressed: () => close(false),
            ),
            PlatformButton(
              platform: widget.platform,
              label: 'Replace library',
              onPressed: () => close(true),
            ),
          ],
        ),
      );
      if (replace == null || !mounted) return;
      importBackup(library!, contents, replace: replace);
      setState(() {
        selected = null;
        collectionId = null;
        error = null;
      });
    } catch (failure) {
      if (mounted) {
        setState(() => error = 'Import failed; library unchanged: $failure');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error!),
            PlatformButton(
              platform: widget.platform,
              label: 'Dismiss',
              onPressed: () => setState(() => error = null),
            ),
          ],
        ),
      );
    }
    if (library == null) {
      return const Center(child: Text('Opening local library…'));
    }
    final records = library!.sources(
      query: query.trim(),
      collectionId: collectionId,
    );
    final groups = library!.collections();
    final narrow = MediaQuery.sizeOf(context).width < 750;
    final list = Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              PlatformField(
                platform: widget.platform,
                label: 'Search source titles',
                onChanged: (value) => setState(() => query = value),
              ),
              Wrap(
                spacing: 8,
                children: [
                  PlatformButton(
                    platform: widget.platform,
                    label: 'All sources',
                    onPressed: () => setState(() => collectionId = null),
                  ),
                  ...groups.map(
                    (group) => PlatformButton(
                      platform: widget.platform,
                      label: group.name,
                      onPressed: () => setState(() => collectionId = group.id),
                    ),
                  ),
                  PlatformButton(
                    platform: widget.platform,
                    label: 'New collection',
                    onPressed: addCollection,
                  ),
                  PlatformButton(
                    platform: widget.platform,
                    label: 'New source',
                    onPressed: () => editSource(),
                  ),
                  PlatformButton(
                    platform: widget.platform,
                    label: 'Import JSON',
                    onPressed: importFile,
                  ),
                  for (final kind in ['json', 'md', 'bib'])
                    PlatformButton(
                      platform: widget.platform,
                      label: 'Export $kind',
                      onPressed: () => saveExport(kind),
                    ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: records.isEmpty
              ? Center(
                  child: Text(
                    query.isEmpty && collectionId == null
                        ? 'No sources yet. Your research stays on this device.'
                        : 'No matching sources.',
                  ),
                )
              : ListView.builder(
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final source = records[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: PlatformButton(
                        platform: widget.platform,
                        label:
                            '${source.title} · ${source.type.name} · ${source.creators.join(', ')}',
                        onPressed: () => setState(() => selected = source),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
    final detail = selected == null
        ? const Center(child: Text('Select a source to read excerpts.'))
        : _detail(selected!, groups, narrow);
    if (!narrow) {
      return Row(
        children: [
          Expanded(flex: 2, child: list),
          const SizedBox(width: 1),
          Expanded(flex: 3, child: detail),
        ],
      );
    }
    if (selected == null) return list;
    return detail;
  }

  Widget _detail(
    Source source,
    List<Collection> groups,
    bool narrow,
  ) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      if (narrow)
        PlatformButton(
          platform: widget.platform,
          label: 'Back to sources',
          onPressed: () => setState(() => selected = null),
        ),
      Text(source.title, style: const TextStyle(fontSize: 24)),
      Text('${source.type.name} · ${source.creators.join(', ')}'),
      if (source.year != null) Text('Year: ${source.year}'),
      if (source.container != null) Text('Container: ${source.container}'),
      if (source.publisher != null) Text('Publisher: ${source.publisher}'),
      if (source.identifier != null) Text('Identifier: ${source.identifier}'),
      Text('Tags: ${library!.tags(source.id).join(', ')}'),
      const Text('Citation draft — proofread before use.'),
      Text(apaReference(source).text ?? 'Citation unavailable'),
      for (final warning in apaReference(source).warnings) Text(warning),
      PlatformButton(
        platform: widget.platform,
        label: 'Copy APA draft',
        onPressed: apaReference(source).text == null
            ? null
            : () => Clipboard.setData(
                ClipboardData(text: apaReference(source).text!),
              ),
      ),
      Wrap(
        spacing: 8,
        children: [
          PlatformButton(
            platform: widget.platform,
            label: 'Edit source',
            onPressed: () => editSource(source),
          ),
          PlatformButton(
            platform: widget.platform,
            label: 'Capture excerpt',
            onPressed: () => addExcerpt(source),
          ),
          for (final group in groups)
            PlatformButton(
              platform: widget.platform,
              label:
                  '${library!.sources(collectionId: group.id).any((item) => item.id == source.id) ? 'Remove from' : 'Add to'} ${group.name}',
              onPressed: () {
                if (library!
                    .sources(collectionId: group.id)
                    .any((item) => item.id == source.id)) {
                  library!.removeFromCollection(source.id, group.id);
                } else {
                  library!.addToCollection(source.id, group.id);
                }
                setState(() {});
              },
            ),
        ],
      ),
      const SizedBox(height: 16),
      const Text('Excerpts', style: TextStyle(fontSize: 20)),
      for (final excerpt in library!.excerpts(source.id))
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                excerpt.locator,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(excerpt.quote),
              if (excerpt.note.isNotEmpty) Text(excerpt.note),
            ],
          ),
        ),
    ],
  );
}

class PlatformButton extends StatelessWidget {
  const PlatformButton({
    super.key,
    required this.platform,
    required this.label,
    required this.onPressed,
  });
  final TargetPlatform platform;
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    if (platform == TargetPlatform.iOS) {
      return cupertino.CupertinoButton(
        onPressed: onPressed,
        child: Text(label),
      );
    }
    if (platform == TargetPlatform.windows) {
      return fluent.Button(onPressed: onPressed, child: Text(label));
    }
    return material.FilledButton(onPressed: onPressed, child: Text(label));
  }
}

class PlatformField extends StatelessWidget {
  const PlatformField({
    super.key,
    required this.platform,
    required this.label,
    this.controller,
    this.onChanged,
    this.keyboardType,
    this.maxLines = 1,
  });
  final TargetPlatform platform;
  final String label;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final int maxLines;
  @override
  Widget build(BuildContext context) {
    if (platform == TargetPlatform.iOS) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Semantics(
          label: label,
          child: cupertino.CupertinoTextField(
            controller: controller,
            placeholder: label,
            onChanged: onChanged,
            keyboardType: keyboardType,
            maxLines: maxLines,
          ),
        ),
      );
    }
    if (platform == TargetPlatform.windows) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Semantics(
          label: label,
          child: fluent.TextBox(
            controller: controller,
            placeholder: label,
            onChanged: onChanged,
            keyboardType: keyboardType,
            maxLines: maxLines,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Semantics(
        label: label,
        child: material.TextField(
          controller: controller,
          decoration: material.InputDecoration(labelText: label),
          onChanged: onChanged,
          keyboardType: keyboardType,
          maxLines: maxLines,
        ),
      ),
    );
  }
}

Future<T?> showDialogForPlatform<T>(
  BuildContext context,
  TargetPlatform platform,
  Widget Function(void Function([T? result]) close) builder,
) {
  if (platform == TargetPlatform.iOS) {
    return cupertino.showCupertinoDialog<T>(
      context: context,
      builder: (dialogContext) => cupertino.CupertinoPopupSurface(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: builder(
                  ([result]) => Navigator.pop(dialogContext, result),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  if (platform == TargetPlatform.windows) {
    return fluent.showDialog<T>(
      context: context,
      builder: (dialogContext) => fluent.ContentDialog(
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: builder(([result]) => Navigator.pop(dialogContext, result)),
          ),
        ),
      ),
    );
  }
  return material.showDialog<T>(
    context: context,
    builder: (dialogContext) => material.AlertDialog(
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: builder(([result]) => Navigator.pop(dialogContext, result)),
        ),
      ),
    ),
  );
}
