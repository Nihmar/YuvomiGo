import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yuvomigo/features/auth/auth_controller.dart';
import 'package:yuvomigo/features/auth/auth_providers.dart';
import 'package:yuvomigo/features/auth/auth_state.dart';
import 'package:yuvomigo/data/repositories/preferences_repository.dart';
import 'package:yuvomigo/features/settings/preferences_providers.dart';
import 'package:yuvomigo/features/theme/theme_picker_button.dart';

/// Impostazioni: profilo, server, tema, festività, logout.
final class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider);
    final user = state is Authenticated ? state.user : null;
    final serverUrl = ref.watch(sessionManagerProvider).session?.serverUrl;
    final prefs = ref.watch(appPreferencesValueProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (user != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(user.displayName),
                subtitle: Text('${user.username} · ${user.role}'),
              ),
            ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.dns_outlined),
                  title: const Text('Server'),
                  subtitle: Text(
                    serverUrl?.isNotEmpty == true ? serverUrl! : 'Sconosciuto',
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Colore tema'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showThemePicker(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.celebration_outlined),
                  title: const Text('Festività'),
                  subtitle: Text(
                    prefs.holidayCountry?.isNotEmpty == true
                        ? prefs.holidayCountry!
                        : 'Non configurate',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _HolidaySettingsDialog.show(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(
                Icons.logout,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Esci',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () => _confirmLogout(context, ref),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'YuvomiGo — client non ufficiale per Yuvomi',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Esci'),
        content: const Text('Vuoi uscire dall\'account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Esci'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(authControllerProvider.notifier).logout();
  }
}

/// Dialog per configurare le festività (paese + visibilità).
final class _HolidaySettingsDialog extends ConsumerStatefulWidget {
  const _HolidaySettingsDialog();

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const _HolidaySettingsDialog(),
    );
  }

  @override
  ConsumerState<_HolidaySettingsDialog> createState() =>
      _HolidaySettingsDialogState();
}

final class _HolidaySettingsDialogState
    extends ConsumerState<_HolidaySettingsDialog> {
  String? _country;
  bool _showPublic = true;
  bool _showSchool = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(appPreferencesValueProvider);
    _country = prefs.holidayCountry;
    _showPublic = prefs.holidayShowPublic;
    _showSchool = prefs.holidayShowSchool;
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(preferencesRepositoryProvider).update({
        'holiday_country': _country,
        'holiday_show_public': _showPublic,
        'holiday_show_school': _showSchool,
      });
      ref.invalidate(appPreferencesProvider);
      if (!mounted) return;
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Salvataggio non riuscito: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final countries = ref.watch(holidayCountriesProvider);
    final loaded = countries.value ?? const <HolidayCountry>[];
    // Il paese salvato potrebbe non essere (più) nella lista: lo aggiungo
    // per non far fallire il dropdown e non perdere la configurazione.
    final items = <HolidayCountry>[
      if (_country != null &&
          _country!.isNotEmpty &&
          !loaded.any((c) => c.isoCode == _country))
        HolidayCountry(isoCode: _country!, name: _country!),
      ...loaded,
    ];

    return AlertDialog(
      title: const Text('Festività'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String?>(
              initialValue: _country,
              decoration: const InputDecoration(labelText: 'Paese'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Nessuno'),
                ),
                for (final country in items)
                  DropdownMenuItem<String?>(
                    value: country.isoCode,
                    child: Text('${country.name} (${country.isoCode})'),
                  ),
              ],
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _country = value),
            ),
            if (countries.isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(),
              ),
            if (countries.hasError)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Lista paesi non disponibile: riprova più tardi.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Festività pubbliche'),
              value: _showPublic,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _showPublic = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Festività scolastiche'),
              value: _showSchool,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _showSchool = value),
            ),
          ],
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
