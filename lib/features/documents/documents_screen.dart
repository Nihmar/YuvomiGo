import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:yuvomigo/core/widgets/error_retry_tile.dart';
import 'package:yuvomigo/features/documents/document_file_picker.dart';
import 'package:yuvomigo/features/documents/document_models.dart';
import 'package:yuvomigo/features/documents/document_providers.dart';

/// Schermata Documenti: metadati con ricerca, upload e archiviazione.
///
/// Download/anteprima richiedono la sessione e restano sul web.
final class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

final class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  static const _scrollPhysics = AlwaysScrollableScrollPhysics();

  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<DocumentItem> _filter(List<DocumentItem> documents) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return documents;
    return documents
        .where(
          (document) =>
              document.name.toLowerCase().contains(query) ||
              (document.description?.toLowerCase().contains(query) ?? false) ||
              (document.folderName?.toLowerCase().contains(query) ?? false),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final documents = ref.watch(documentsProvider);
    ref.listen<Object?>(documentsActionErrorProvider, (_, err) {
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Operazione non riuscita: $err')),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Documenti')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                labelText: 'Cerca documento',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await ref.read(documentsProvider.notifier).refresh();
              },
              child: documents.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ListView(
                  physics: _scrollPhysics,
                  padding: const EdgeInsets.all(16),
                  children: [
                    ErrorRetryTile(
                      message: 'Impossibile caricare i documenti.',
                      detail: e.toString(),
                      onRetry: () =>
                          ref.read(documentsProvider.notifier).load(),
                    ),
                  ],
                ),
                data: (all) {
                  final list = _filter(all);
                  if (list.isEmpty) {
                    return ListView(
                      physics: _scrollPhysics,
                      padding: const EdgeInsets.all(24),
                      children: [
                        Text(
                          all.isEmpty
                              ? 'Nessun documento.'
                              : 'Nessun documento per "$_query".',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    );
                  }
                  return ListView.builder(
                    physics: _scrollPhysics,
                    padding: const EdgeInsets.only(bottom: 88),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final document = list[index];
                      return ListTile(
                        leading: const Icon(Icons.description_outlined),
                        title: Text(document.name),
                        subtitle: Text(_subtitle(document)),
                        onTap: () => _showDetail(document),
                        trailing: IconButton(
                          tooltip: 'Archivia',
                          icon: const Icon(Icons.archive_outlined),
                          onPressed: () => _confirmArchive(document),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Carica documento',
        onPressed: _pickAndUpload,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _pickAndUpload() async {
    final picked = await ref.read(documentFilePickerProvider).pick();
    if (picked == null || !mounted) return;
    final mimeType = documentMimeForName(picked.name);
    if (mimeType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tipo di file non supportato (PDF, immagini, testo/CSV, Office).',
          ),
        ),
      );
      return;
    }
    await _UploadDocumentDialog.show(
      context,
      picked: picked,
      mimeType: mimeType,
    );
  }

  Future<void> _confirmArchive(DocumentItem document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archivia documento'),
        content: Text('Vuoi archiviare "${document.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Archivia'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(documentsProvider.notifier).archive(document.id);
  }

  String _subtitle(DocumentItem document) {
    final parts = <String>[];
    if (document.folderName?.isNotEmpty == true) {
      parts.add(document.folderName!);
    }
    if (document.category.isNotEmpty) {
      parts.add(documentCategoryLabel(document.category));
    }
    final size = formatFileSize(document.fileSize);
    if (size.isNotEmpty) parts.add(size);
    return parts.join(' · ');
  }

  void _showDetail(DocumentItem document) {
    final locale = Localizations.localeOf(context).toString();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                document.name,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              if (document.description?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text(document.description!),
              ],
              const SizedBox(height: 12),
              _DetailRow(label: 'Cartella', value: document.folderName),
              _DetailRow(
                label: 'Categoria',
                value: document.category.isEmpty
                    ? null
                    : documentCategoryLabel(document.category),
              ),
              _DetailRow(label: 'File', value: document.originalName),
              _DetailRow(label: 'Tipo', value: document.mimeType),
              _DetailRow(
                label: 'Dimensione',
                value: formatFileSize(document.fileSize),
              ),
              _DetailRow(label: 'Caricato da', value: document.creatorName),
              _DetailRow(
                label: 'Aggiornato',
                value: _formatDate(document.updatedAt, locale),
              ),
              if (document.externalUrl?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Text(
                  'Link esterno',
                  style: Theme.of(sheetContext).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                SelectableText(document.externalUrl!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String? _formatDate(String? raw, String locale) {
    final date = raw == null ? null : DateTime.tryParse(raw)?.toLocal();
    if (date == null) return null;
    return DateFormat('d MMM yyyy, HH:mm', locale).format(date);
  }
}

final class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: Text(value!)),
        ],
      ),
    );
  }
}

/// Dialog per completare i metadati prima dell'upload.
final class _UploadDocumentDialog extends ConsumerStatefulWidget {
  const _UploadDocumentDialog({required this.picked, required this.mimeType});

  final PickedDocumentFile picked;
  final String mimeType;

  static Future<void> show(
    BuildContext context, {
    required PickedDocumentFile picked,
    required String mimeType,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => _UploadDocumentDialog(picked: picked, mimeType: mimeType),
    );
  }

  @override
  ConsumerState<_UploadDocumentDialog> createState() =>
      _UploadDocumentDialogState();
}

final class _UploadDocumentDialogState
    extends ConsumerState<_UploadDocumentDialog> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  String _category = 'other';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final dot = widget.picked.name.lastIndexOf('.');
    _name.text = dot > 0
        ? widget.picked.name.substring(0, dot)
        : widget.picked.name;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    final description = _description.text.trim();
    final success = await ref
        .read(documentsProvider.notifier)
        .upload(
          name: name,
          originalName: widget.picked.name,
          mimeType: widget.mimeType,
          bytes: widget.picked.bytes,
          category: _category,
          description: description.isEmpty ? null : description,
        );
    if (!mounted) return;
    if (!success) {
      setState(() => _busy = false);
      return;
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Carica documento'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${widget.picked.name} · '
                '${formatFileSize(widget.picked.bytes.length)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nome'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Categoria'),
                items: [
                  for (final category in documentCategories)
                    DropdownMenuItem(
                      value: category,
                      child: Text(documentCategoryLabel(category)),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _category = value ?? 'other'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Descrizione (opzionale)',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Carica'),
        ),
      ],
    );
  }
}
