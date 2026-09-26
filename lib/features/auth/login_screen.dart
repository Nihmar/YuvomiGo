import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yuvomigo/core/api/api_error.dart';
import 'package:yuvomigo/core/utils/url_utils.dart';
import 'package:yuvomigo/features/auth/auth_controller.dart';
import 'package:yuvomigo/features/auth/auth_state.dart';
import 'package:yuvomigo/features/auth/server_settings.dart';

/// Schermata di login: URL server + username + password (e 2FA opzionale).
final class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

final class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();

  String? _error;
  bool _submitting = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _prefillServerUrl();
  }

  /// Precompila l'URL del server usato all'ultimo login.
  Future<void> _prefillServerUrl() async {
    try {
      final url = await ref.read(serverUrlMemoryProvider).read();
      if (mounted && url != null && _urlController.text.isEmpty) {
        _urlController.text = url;
      }
    } catch (_) {
      // Storage non disponibile: il campo resta vuoto, il login resta usabile.
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submitCredentials() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _error = null;
      _submitting = true;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .login(
            serverUrl: _urlController.text,
            username: _usernameController.text.trim(),
            password: _passwordController.text,
          );
      // Login ok (o 2FA): ricordiamo il server per la prossima volta.
      await ref
          .read(serverUrlMemoryProvider)
          .remember(normalizeServerUrl(_urlController.text.trim()));
      // Su successo il router reindirizza automaticamente a home.
      // Resetto comunque lo spinner: in caso di 2FA si resta su questo
      // screen (form del codice) e il bottone deve restare premibile.
      if (mounted) {
        setState(() => _submitting = false);
      }
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _submitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Errore imprevisto: $e';
          _submitting = false;
        });
      }
    }
  }

  Future<void> _submit2FA() async {
    if (_codeController.text.trim().isEmpty) return;
    setState(() {
      _error = null;
      _submitting = true;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .verifyTwoFactor(_codeController.text.trim());
      // Su successo il router reindirizza a home.
      if (mounted) {
        setState(() => _submitting = false);
      }
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _submitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Errore imprevisto: $e';
          _submitting = false;
        });
      }
    }
  }

  /// Torna al form con username/password (annulla il 2FA in corso).
  Future<void> _cancelTwoFactor() async {
    setState(() => _error = null);
    await ref.read(authControllerProvider.notifier).cancelTwoFactor();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final pending2FA = state is AuthPending2FA;

    return Scaffold(
      appBar: AppBar(title: const Text('YuvomiGo')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Text(
                      'Accedi al tuo server Yuvomi',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 24),
                    if (_error != null)
                      _errorBox(context, _error!)
                    else
                      const SizedBox.shrink(),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _urlController,
                      decoration: const InputDecoration(
                        labelText: 'URL server',
                        hintText: 'http://domini-o-nas:4000',
                        prefixIcon: Icon(Icons.link),
                      ),
                      validator: validateServerUrl,
                      keyboardType: TextInputType.url,
                      autofillHints: const [AutofillHints.url],
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    if (!pending2FA) ...[
                      TextFormField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Inserisci l\'username.'
                            : null,
                        autofillHints: const [AutofillHints.username],
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'Mostra password'
                                : 'Nascondi password',
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Inserisci la password.'
                            : null,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) {
                          if (!_submitting) _submitCredentials();
                        },
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _submitting ? null : _submitCredentials,
                        icon: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.login),
                        label: const Text('Accedi'),
                      ),
                    ] else ...[
                      Text(
                        'Inserisci il codice del secondo fattore'
                        '${state.recoveryAvailable ? ' (o un recovery code)' : ''}.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _codeController,
                        decoration: const InputDecoration(
                          labelText: 'Codice',
                          prefixIcon: Icon(Icons.pin),
                        ),
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) {
                          if (!_submitting) _submit2FA();
                        },
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _submitting ? null : _submit2FA,
                        icon: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.verified),
                        label: const Text('Verifica'),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _submitting ? null : _cancelTwoFactor,
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Usa un altro account'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorBox(BuildContext context, String message) {
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
