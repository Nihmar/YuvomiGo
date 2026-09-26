import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yuvomigo/core/widgets/error_retry_tile.dart';
import 'package:yuvomigo/features/meals/meal_models.dart';
import 'package:yuvomigo/features/recipes/recipe_models.dart';
import 'package:yuvomigo/features/recipes/recipe_providers.dart';

/// Schermata Ricette: elenco con ricerca e dettaglio ingredienti.
final class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({super.key});

  @override
  ConsumerState<RecipesScreen> createState() => _RecipesScreenState();
}

final class _RecipesScreenState extends ConsumerState<RecipesScreen> {
  static const _scrollPhysics = AlwaysScrollableScrollPhysics();

  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Recipe> _filter(List<Recipe> recipes) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return recipes;
    return recipes
        .where((recipe) => recipe.title.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final recipes = ref.watch(recipesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ricette')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                labelText: 'Cerca ricetta',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(recipesProvider);
                try {
                  await ref.read(recipesProvider.future);
                } catch (_) {
                  // L'errore è già nello stato del provider.
                }
              },
              child: recipes.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ListView(
                  physics: _scrollPhysics,
                  padding: const EdgeInsets.all(16),
                  children: [
                    ErrorRetryTile(
                      message: 'Impossibile caricare le ricette.',
                      detail: e.toString(),
                      onRetry: () => ref.invalidate(recipesProvider),
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
                              ? 'Nessuna ricetta.'
                              : 'Nessuna ricetta per "$_query".',
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
                      final recipe = list[index];
                      return ListTile(
                        leading: const Icon(Icons.menu_book_outlined),
                        title: Text(recipe.title),
                        subtitle: Text(_subtitle(recipe)),
                        onTap: () => _showDetail(recipe),
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

  String _subtitle(Recipe recipe) {
    final parts = <String>[];
    if (recipe.ingredients.isNotEmpty) {
      parts.add('${recipe.ingredients.length} ingredienti');
    }
    if (recipe.mealTypes.isNotEmpty) {
      parts.add(recipe.mealTypes.map(mealTypeLabel).join(', '));
    }
    if (recipe.source != 'native') parts.add('esterna');
    return parts.join(' · ');
  }

  void _showDetail(Recipe recipe) {
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
                recipe.title,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              if (recipe.mealTypes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final type in recipe.mealTypes)
                      Chip(
                        label: Text(mealTypeLabel(type)),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'Ingredienti',
                style: Theme.of(sheetContext).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              if (recipe.ingredients.isEmpty)
                const Text('Nessun ingrediente.')
              else
                for (final ingredient in recipe.ingredients)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      ingredient.quantity?.isNotEmpty == true
                          ? '• ${ingredient.name} (${ingredient.quantity})'
                          : '• ${ingredient.name}',
                    ),
                  ),
              if (recipe.notes?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Text(
                  'Note',
                  style: Theme.of(sheetContext).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(recipe.notes!),
              ],
              if (recipe.recipeUrl?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Text(
                  'Fonte',
                  style: Theme.of(sheetContext).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                SelectableText(recipe.recipeUrl!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
