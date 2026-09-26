import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:yuvomigo/core/widgets/error_retry_tile.dart';
import 'package:yuvomigo/features/documents/document_models.dart';
import 'package:yuvomigo/features/documents/document_providers.dart';

/// Schermata Documenti: metadati con ricerca e dettaglio.
///
/// Sola lettura: download/anteprima richiedono la sessione e restano sul web.
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
                ref.invalidate(documentsProvider);
                try {
                  await ref.read(documentsProvider.future);
                } catch (_) {
                  // L'errore è già nello stato del provider.
                }
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
                      onRetry: () => ref.invalidate(documentsProvider),
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
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final document = list[index];
                      return ListTile(
                        leading: const Icon(Icons.description_outlined),
                        title: Text(document.name),
                        subtitle: Text(_subtitle(document)),
                        onTap: () => _showDetail(document),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
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
