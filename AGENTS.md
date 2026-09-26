# AGENTS.md — YuvomiGo Workspace

Workspace per il client Flutter di Yuvomi (app: YuvomiGo).
Contiene sia il riferimento upstream sia l'app.

Percorso workspace: /home/alessandro/Projects/YuvomiGo/

## Struttura
- **Repository git: root del workspace** (`.git/` qui). `PLAN.md`, `AGENTS.md`, `scripts/` e `app/`
  sono versionati; `reference/` e `scripts/.env` sono in `.gitignore` (mai committarli).
- `reference/` — snapshot READ-ONLY delle release upstream di Yuvomi.
  - `reference/<tag>/` — contenuto di una release
  - `reference/current` — symlink alla release in uso
  - **Non modificare nulla qui.**
- `app/` — progetto Flutter YuvomiGo, l'unica cosa modificabile.
  - `app/api/openapi.json` — specifica OpenAPI scaricata dal server Yuvomi (non editare a mano)
  - `app/api/.yuvomi-version` — versione Yuvomi da cui proviene la spec
  - `app/lib/data/generated/` — client Dart generato (non editare a mano)
  - `app/lib/data/repositories/` — qui si adattano le API changes
  - `app/test/` — test (widget + provider); una feature senza test non è completa
- `scripts/` — script di aggiornamento
  - `scripts/.env` — credenziali del server (token admin in chiaro; **mai committare in git**)
- `.github/workflows/ci.yml` — CI (format + analyze + test), esegue in `app/` (`working-directory`)
- `PLAN.md` — piano di sviluppo e decisioni prese

## Piattaforme target
Android, Windows, Linux. iOS e macOS esclusi (impossibile compilarli in questo ambiente).

## Decisioni chiave (dettagli in PLAN.md)
- MVP: Dashboard, Tasks, Shopping, Calendar, Notes
- UI: Material Design standard (non il tema web upstream)
- Generazione API: `dart_openapi_generator` + build_runner (client Dio, no JVM)
- State management: Riverpod · HTTP: Dio · Routing: go_router
- Token: `flutter_secure_storage`
- Login: screen con **URL server + username + password**; connessione http e https (URL persistito nei settings)

## Regole
1. NON modificare `reference/`, `app/api/openapi.json` né `app/lib/data/generated/`.
2. Modifica solo `app/lib/` (repository, provider, UI) e `scripts/`.
3. **Test obbligatori**: ogni feature aggiunta deve avere i suoi test (widget test per l'UI, test dei provider/repository per la logica).
4. **Committi frequenti**: lavorare con committi piccoli e incrementali.
5. **Prima di ogni commit**: eseguire `cd app && flutter test` e `flutter analyze` — entrambi devono passare. Niente commit con test rotti o analysis in errore.
6. Quando l'API upstream cambia:
   - Lancia `./scripts/update-openapi.sh` (scarica la spec nuova dal server e rigenera il client).
   - Confronta la spec vecchia con la nuova (`git diff` su `app/api/openapi.json` prima del commit).
   - Identifica breaking changes (campi rinominati, enum nuovi, endpoint rimossi).
   - Adatta `app/lib/data/repositories/` e i provider Riverpod che espongono i dati.
   - Aggiorna i test e verifica che passino.

## Comandi
- Aggiornare a una release: `./scripts/full-update.sh v2.64.0` (fetch reference + rigenera la spec dal server live)
- Rigenerare client: `./scripts/update-openapi.sh`
- Test: `cd app && flutter test`
- Analisi statica: `cd app && flutter analyze`
- **Check pre-commit**: `./scripts/check.sh` (format check + analyze + test)

## Convenzioni
- State management: Riverpod
- HTTP: Dio
- Generazione: `dart_openapi_generator` + build_runner
- UI: Material Design standard (light/dark via `ThemeData`)
- Naming: snake_case per file, PascalCase per classi
- Test: `flutter_test` per i widget, test dei provider con Riverpod
