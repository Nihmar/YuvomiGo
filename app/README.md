# YuvomiGo

Client Flutter **non ufficiale** per [Yuvomi](https://github.com/ulsklyc/yuvomi),
il family organizer self-hosted.

**Piattaforme supportate**: Android, Windows, Linux (iOS/macOS esclusi).

## Requisiti

- Flutter (canale stable)
- **Android**: Android SDK + toolchain per `flutter build apk`
- **Linux desktop**: `libsecret-1-dev` (build) e `libsecret-1-0` (runtime),
  richiesti da `flutter_secure_storage`; senza di essi il login non riesce a
  salvare la sessione (l'app resta usabile ma non ricorda l'accesso)
- **Windows**: toolchain Visual Studio come da `flutter doctor`

## Avvio

```bash
flutter pub get
flutter run -d <device>
```

Al primo avvio: URL del server (es. `http://omvnas:4000` o `https://...`),
username e password. L'URL viene ricordato per i login successivi; per HTTPS
con certificato self-signed c'è l'opzione "Accetta certificati self-signed".

## Comandi

```bash
flutter test                 # suite di test
flutter analyze              # analisi statica
../scripts/check.sh          # format + analyze + test (pre-commit)
../scripts/update-openapi.sh # rigenera il client dall'OpenAPI del server
../scripts/build-apk.sh      # build APK (debug/release)
```

## Struttura

- `lib/core/` — API (Dio + interceptor sessione/CSRF), errori tipizzati, utils
- `lib/data/repositories/` — adattatori verso l'API (raw Dio dove la spec non
  ha schema di risposta)
- `lib/data/generated/` — client Dart generato: **non modificare a mano**
- `lib/features/` — moduli (auth, dashboard, tasks, shopping, calendar, notes,
  settings, theme) con model, provider Riverpod e screen
- `api/openapi.json` — spec OpenAPI del server di riferimento (versionata)

## Note

- Documentazione di progetto: [`../PLAN.md`](../PLAN.md) e
  [`../AGENTS.md`](../AGENTS.md).
- CI: `.github/workflows/ci.yml` (format + analyze + test).
