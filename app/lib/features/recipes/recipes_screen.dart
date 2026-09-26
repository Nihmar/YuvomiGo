import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yuvomigo/core/widgets/error_retry_tile.dart';
import 'package:yuvomigo/features/meals/meal_models.dart';
import 'package:yuvomigo/features/recipes/recipe_models.dart';
import 'package:yuvomigo/features/recipes/recipe_providers.dart';

/// Schermata Ricette: elenco con ricerca, dettaglio e CRUD delle ricette native.
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
    ref.listen<Object?>(recipesActionErrorProvider, (_, err) {
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Operazione non riuscita: $err')),
        );
      }
    });

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
              onRefresh: () => ref.read(recipesProvider.notifier).refresh(),
              child: recipes.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ListView(
                  physics: _scrollPhysics,
                  padding: const EdgeInsets.all(16),
                  children: [
                    ErrorRetryTile(
                      message: 'Impossibile caricare le ricette.',
                      detail: e.toString(),
                      onRetry: () => ref.read(recipesProvider.notifier).load(),
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
                              ? 'Nessuna ricetta.\nUsa "Aggiungi" per crearne una.'
                              : 'Nessuna ricetta per "$_query".',
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
      floatingActionButton: FloatingActionButton(
        tooltip: 'Aggiungi ricetta',
        onPressed: () => _RecipeEditorDialog.show(context),
        child: const Icon(Icons.add),
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
    final isNative = recipe.source == 'native';
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
              if (!isNative) ...[
                const SizedBox(height: 12),
                Text(
                  'Ricetta importata da un provider: si modifica alla fonte.',
                  style: Theme.of(sheetContext).textTheme.bodySmall,
                ),
              ] else ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _RecipeEditorDialog.show(context, recipe: recipe);
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Modifica'),
                    ),
                    const SizedBox(width: 12),
                    TextButton.icon(
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();
                        await _confirmDelete(recipe);
                      },
                      icon: Icon(
                        Icons.delete_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      label: Text(
                        'Elimina',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Recipe recipe) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Elimina ricetta'),
        content: Text('Vuoi eliminare "${recipe.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(recipesProvider.notifier).remove(recipe.id);
  }
}

/// Dialog per creare/modificare una ricetta (con i suoi ingredienti).
final class _RecipeEditorDialog extends ConsumerStatefulWidget {
  const _RecipeEditorDialog({this.recipe});

  final Recipe? recipe;

  static Future<void> show(BuildContext context, {Recipe? recipe}) {
    return showDialog<void>(
      context: context,
      builder: (_) => _RecipeEditorDialog(recipe: recipe),
    );
  }

  @override
  ConsumerState<_RecipeEditorDialog> createState() =>
      _RecipeEditorDialogState();
}

final class _RecipeEditorDialogState
    extends ConsumerState<_RecipeEditorDialog> {
  static const _mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];

  final _title = TextEditingController();
  final _notes = TextEditingController();
  final _url = TextEditingController();
  final Set<String> _selectedMealTypes = {};
  final List<_IngredientDraft> _ingredients = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final recipe = widget.recipe;
    if (recipe == null) {
      _ingredients.add(_IngredientDraft());
      return;
    }
    _title.text = recipe.title;
    _notes.text = recipe.notes ?? '';
    _url.text = recipe.recipeUrl ?? '';
    _selectedMealTypes.addAll(recipe.mealTypes);
    for (final ingredient in recipe.ingredients) {
      _ingredients.add(
        _IngredientDraft(
          name: ingredient.name,
          quantity: ingredient.quantity ?? '',
          category: ingredient.category,
        ),
      );
    }
    if (_ingredients.isEmpty) _ingredients.add(_IngredientDraft());
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _url.dispose();
    for (final ingredient in _ingredients) {
      ingredient.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final ingredients = [
      for (final draft in _ingredients)
        if (draft.name.text.trim().isNotEmpty)
          RecipeIngredient(
            name: draft.name.text.trim(),
            quantity: draft.quantity.text.trim().isEmpty
                ? null
                : draft.quantity.text.trim(),
            category: draft.category,
          ),
    ];
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    final notifier = ref.read(recipesProvider.notifier);
    final notes = _notes.text.trim();
    final url = _url.text.trim();
    final recipe = widget.recipe;
    final success = recipe == null
        ? await notifier.add(
            title: title,
            notes: notes.isEmpty ? null : notes,
            recipeUrl: url.isEmpty ? null : url,
            mealTypes: _selectedMealTypes.toList(),
            ingredients: ingredients,
          )
        : await notifier.update(
            recipe.id,
            title: title,
            notes: notes.isEmpty ? null : notes,
            recipeUrl: url.isEmpty ? null : url,
            mealTypes: _selectedMealTypes.toList(),
            ingredients: ingredients,
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
    final isEdit = widget.recipe != null;
    return AlertDialog(
      title: Text(isEdit ? 'Modifica ricetta' : 'Nuova ricetta'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _title,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Titolo'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                children: [
                  for (final type in _mealTypes)
                    FilterChip(
                      label: Text(mealTypeLabel(type)),
                      selected: _selectedMealTypes.contains(type),
                      onSelected: _busy
                          ? null
                          : (selected) => setState(() {
                              if (selected) {
                                _selectedMealTypes.add(type);
                              } else {
                                _selectedMealTypes.remove(type);
                              }
                            }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Ingredienti',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 4),
              for (var i = 0; i < _ingredients.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _ingredients[i].name,
                          decoration: const InputDecoration(
                            labelText: 'Ingrediente',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _ingredients[i].quantity,
                          decoration: const InputDecoration(
                            labelText: 'Quantità',
                            isDense: true,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Rimuovi ingrediente',
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                _ingredients.removeAt(i).dispose();
                              }),
                      ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _busy
                      ? null
                      : () => setState(
                          () => _ingredients.add(_IngredientDraft()),
                        ),
                  icon: const Icon(Icons.add),
                  label: const Text('Aggiungi ingrediente'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Note (opzionale)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _url,
                decoration: const InputDecoration(
                  labelText: 'URL fonte (opzionale)',
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
              : const Text('Salva'),
        ),
      ],
    );
  }
}

/// Bozza di ingrediente nel dialog (controller per riga).
final class _IngredientDraft {
  _IngredientDraft({String name = '', String quantity = '', this.category = ''})
    : name = TextEditingController(text: name),
      quantity = TextEditingController(text: quantity);

  final TextEditingController name;
  final TextEditingController quantity;
  final String category;

  void dispose() {
    name.dispose();
    quantity.dispose();
  }
}
