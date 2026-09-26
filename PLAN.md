# PLAN.md — YuvomiGo: Piano di sviluppo

## Obiettivo
Client Flutter per **Yuvomi** (family organizer self-hosted: task, calendario, spesa, pasti, budget, 20+ moduli).
Backend upstream: https://github.com/ulsklyc/yuvomi — REST API con OpenAPI 3.1, auth Bearer.

## Contesto tecnico
- Backend in uso: **v2.67.0** → 431 endpoint, ~135 schema, ~30 tag/moduli
- Spec OpenAPI: `GET /api/v1/openapi.json` sul server live (richiede token admin) → salvata in `app/api/openapi.json`
- Reference upstream: snapshot read-only in `reference/` per confrontare il sorgente del backend
- Server di riferimento: `http://omvnas:4000` (config in `scripts/.env`)

## Decisioni prese
| Area | Decisione | Note |
|---|---|---|
| Moduli MVP | **Dashboard, Tasks, Shopping, Calendar, Notes** | Gli altri moduli arriveranno in M3+ su richiesta |
| Piattaforme | **Android, Windows, Linux** | iOS/macOS esclusi: non è possibile compilarli |
| Generatore API | **`dart_openapi_generator`** + build_runner | Native Dart, genera model + service Dio, no JVM. pkg v0.3.x |
| UI | **Material Design standard** | Tema light/dark via `ThemeData`; non seguire il tema web upstream |
| State management | **Riverpod** | `flutter_riverpod` |
| HTTP | **Dio** | Interceptor Bearer, base URL configurabile |
| Routing | **go_router** | Default nav con bottom bar + pagine moduli |
| Token storage | **flutter_secure_storage** | Persiste cookie di sessione + CSRF token |
| Auth | **Cookie session + X-CSRF-Token** (come il web) | `POST /auth/login` crea la sessione (cookie `yuvomi.sid`); le state-changing requests mandano `X-CSRF-Token`. I Bearer API token si creano solo da admin (`POST /auth/api-tokens`), non generalizzabile. 2FA opzionale: login risponde `twoFactorRequired` → `POST /auth/2fa/verify` |
| Login / connessione | **Screen login con 3 campi: URL server, username, password** | Il collegamento deve funzionare sia con **http** che con **https**; l'URL inserito viene persistito (settings) e riusato ai login successivi |
| Test | **Test per ogni feature**; `flutter test` + `flutter analyze` prima di ogni commit | Widget test + provider tests |
| Repo git | **Root del workspace** | `app/` è una sottocartella; `scripts/.env` e `reference/` in `.gitignore`; CI in `.github/workflows/ci.yml` con `working-directory: app` |

### Dipendenze (versioni di riferimento, da confermare con `flutter pub outdated`)
| Package | Versione | Tipo |
|---|---|---|
| dio | ^5.11 | dep |
| flutter_riverpod | ^3.4 | dep |
| go_router | ^18 | dep |
| flutter_secure_storage | ^11 | dep |
| intl | ^0.20 | dep |
| build_runner | ^2.16 | dev |
| dart_openapi_generator | ^0.3 | dev |
| riverpod (test helpers) | ^3.4 | dev |

## Setup generazione (M0)
```yaml
# app/build.yaml
targets:
  $default:
    builders:
      dart_openapi_generator:
        options:
          input_spec: "api/openapi.json"
          output_dir: "lib/data/generated"
          client_name: "YuvomiApiClient"
          date_time_converter: "iso8601"
```
Output generato in `app/lib/data/generated/`:
- barrel `generated.dart`, `api_client.dart` (aggregatore: un field per tag + auth factory)
- `models/` — un file per schema (~135)
- `services/` — un file per tag (~30)

Note: la spec deve essere un file locale (il builder non scarica da rete) → il flusso resta
fetch spec (`curl` in `update-openapi.sh`) → `dart run build_runner build --delete-conflicting-outputs`.

## Milestone

### M0 — Fondamenta e pipeline (prerequisito di tutto) — **FATTO**
- [x] `pubspec.yaml`: dipendenze + dev deps
- [x] `build.yaml` con il builder `dart_openapi_generator`
- [x] `./scripts/update-openapi.sh` end-to-end (sanitizza la spec, parse versione, rigenera il client)
- [x] Correzioni script (vedi "Fix script" sotto)
- [x] Client generato `YuvomiApiClient` (393 file) committato + wrapper `YuvomiApi`
- [x] Auth: **screen login con URL server + username + password** (http/https),
      cookie session + CSRF in secure storage, 2FA, `GET /auth/me`, logout
      (AuthController + SessionManager + AuthInterceptor: inietta Cookie/CSRF,
      cattura Set-Cookie, bootstrap con GET /auth/me)
- [x] Supporto **http e https**: Android `usesCleartextTraffic=true` nel manifest
      (Windows/Linux: http funziona già)
- [x] Git: commit incrementali (scaffolding, core, auth, shell, client generato, test)
- [x] `app/api/openapi.json` committato
- **Deliverable**: app che si lancia, si logga, mostra home post-login; 28 test + analyze verdi
- [ ] **Verifica sul device**: login reale su `http://omvnas:4000` (Android desktop/Windows)
      → da fare come smoke test manuale (l'ambiente non ha emulator/dispositivo)

### M1 — Skeleton + Dashboard ✅
- [x] Routing go_router: `ShellRoute` con bottom NavigationBar (Dashboard, Task, Spesa, Calendario, Note) + pagine moduli
- [x] Tema Material standard light/dark (già in M0, via `ThemeData`/`ColorScheme.fromSeed`)
- [x] `GET /api/v1/dashboard` → pagina dashboard con le tile (task urgenti + conteggi, eventi prossimi, spesa, note pinnate)
- [x] Refresh state (pull-to-refresh) + 401 → redirect login (il 401 è intercettato dall'interceptor: `state = AuthUnauthenticated()` → router ri-naviga a `/login`)
- [x] Test: model parsing, repository (adapter fake), provider, widget (tile/vuoto/errore) + shell (5 tab, navigazione)
- **Nota**: la risposta dashboard **non è in spec OpenAPI** (il client generato la restituisce `void`) → parse a mano in `DashboardData.fromJson` + `DashboardRepository` con richiesta raw via Dio
- **Deliverable**: skeleton navigabile con dashboard reale

#### Decisioni M1
- La dashboard usa la risposta aggregata dell'endpoint (task/eventi/spesa/note dei moduli MVP); le tile restano "glanceable" (max 5 righe) e il dettaglio va nei moduli (M2)
- Tab attive: indice tenuto nello state della shell (le tab sono l'unica navigazione interna); redirect auth + `initialLocation: /dashboard`

### M2 — Moduli MVP — **FATTO**
- **Tasks** (sottoinsieme MVP): lista aperte ordinate per due_date, crea, completa (toggle
  done/open), delete. Fuori MVP: ricorrenti, template, subtask, categorie/tag, filtri avanzati.
- **Shopping**: liste (con conteggi) + dettaglio articoli (checkbox, aggiungi con quantità,
  delete); crea/rinomina/elimina liste.
- **Calendar** (read-only): eventi prossimi 7 giorni raggruppati per giorno. Fuori MVP:
  creazione/ricorrenze, vista mese/settimana completa, assignee famiglia.
- **Notes**: lista (pinned prima), crea/edita (titolo opz. + contenuto + fissa), delete, pin.
- [x] Ogni modulo: repository raw via Dio (le API non hanno schema response in spec),
      provider Riverpod (NotifierProvider autoDispose), screen Material standard.
- [x] Test per ogni feature (repository con adapter fake + widget con repository fake).
- **Note tecniche** (Riverpod 3.x):
  - `NotifierProvider.autoDispose<T, S>(T.new)` → factory (tear-off), non istanza.
  - `ref.listen` (widget) non ha `fireImmediately`; il fetch iniziale parte in un
    `Future.microtask(load)` dentro `build()` (modificare `state` nel lifecycle è vietato).
  - Guard `_loading` anti-ri-entry sul load.
- **Deliverable**: app usabile giorno per giorno per i 5 moduli ✅ (APK debug/release)

#### Decisioni M2
- Le API di task/shopping/calendar/note NON hanno schema response in spec: i repository
  fanno richieste raw via Dio e parseano nei model di dominio (stesso wrapping `{ data: ... }`).
- Campi dei model ricavati dal web reference (public/pages/*.js) quando la spec è muta.
- Calendar read-only per l'MVP (la vista completa + creazione è M3).

### Hardening post code review — **FATTO**
Fix applicati in ordine di gravità (commit piccoli, test per ognuno):
- [x] **401 globale**: `AuthInterceptor.onError` → logout locale + `AuthUnauthenticated` → router a `/login`
      (le route `/auth/login` e `/auth/2fa/verify` escluse: il loro 401 è gestito inline dal form)
- [x] **Rotazione CSRF**: cattura dell'header `X-CSRF-Token` su ogni risposta (`SessionManager.setCsrfToken`)
- [x] **Bootstrap/logout robusti**: storage che lancia non blocca più lo splash; logout azzera lo stato locale
      anche se server o storage falliscono
- [x] **Errori tipizzati**: helper `mapApiErrors` nei repository → la UI non vede mai `DioException`
- [x] **Spesa**: conteggi delle liste sincronizzati con add/toggle/remove degli articoli; titolo lista nel dettaglio
- [x] **Calendario**: orari nel fuso locale (`toLocal`) e finestra di 7 giorni reali (era 8)
- [x] **Dashboard**: pull-to-refresh affidabile anche con contenuto corto, errore del refresh non più sciolto
- [x] **Task**: fetch `status=open&status=in_progress` (le task "in corso" non spariscono più) + etichetta
- [x] **Note**: il pin riordina subito; un salvataggio fallito non chiude più l'editor (bozza preservata)
- [x] **Shell**: tab selezionata derivata dalla route (niente indice stantio)
- [x] **Igiene**: `dart format` applicato a lib/test, `scripts/check.sh` (format+analyze+test)

Test: 113 verdi, `flutter analyze` pulito.

### Backlog post-review — **FATTO**
- [x] **Login UX**: mostra/nascondi password, `autofillHints`, ritorno alle credenziali dal 2FA
- [x] **Refresh/retry uniformi**: widget `ErrorRetryTile` condiviso + pull-to-refresh su Task/Note/Calendario/Spesa;
      `refresh()` preserva i dati a schermo se la rete fallisce (con SnackBar); guardie `ref.mounted`
      sui provider autoDispose per evitare scritture dopo lo smontaggio
- [x] **i18n**: `flutter_localizations`, locale `it`, date localizzate
- [x] **HTTPS self-signed**: opzione "Accetta certificati self-signed" nel login (persistita, usata anche al bootstrap)
- [x] **Settings**: schermata profilo/server/tema/logout, raggiungibile da tutte le tab (icona ingranaggio)
- [x] **Task**: creazione con data di scadenza e priorità (date picker + dropdown)
- [x] **Note**: scelta del colore nell'editor e pallino colorato in lista
- [x] **Spesa**: scelta della categoria quando si aggiunge un articolo
- [x] **CI/Docs**: workflow GitHub Actions (format+analyze+test), README reale,
      requisiti `libsecret` su Linux documentati
- [x] **Ordinamento task**: mantenuto due_date (divergenza dal server documentata in `task_models.dart`)

Test: 130 verdi, `flutter analyze` pulito.

### M3 — Completamento ed estensioni
- [x] **Settings**: profilo, server URL, tema, logout da tutte le tab, preferenze festività
      (paese + festività pubbliche/scolastiche → `PUT /preferences`)
- [ ] Push notifications: **decisione rinviata**. L'API espone Web Push (VAPID) pensato per il browser;
      FCM richiederebbe supporto server-side che Yuvomi non ha. Per ora: nessuna push, i moduli si
      aggiornano al pull-to-refresh; da rivalutare se upstream aggiunge un canale nativo
- [x] **Moduli extra** (raggiungibili dal menu "Altri moduli" accanto alle 5 tab MVP):
  - [x] **Pasti**: settimana lunedì–domenica con navigazione, creazione (tipo/titolo/data),
        eliminazione; tile "Oggi si mangia" in dashboard
  - [x] **Compleanni**: lista ordinata per prossimo compleanno con countdown/età, creazione,
        modifica, eliminazione
  - [x] **Promemoria**: in scadenza dal server, con "fatto" (dismiss) ed eliminazione
  - [x] **Budget** (sola lettura): mese con navigazione, entrate/uscite/saldo, totali per categoria,
        lista movimenti, confronto col mese precedente (`/budget/stats`); valuta dalle preferenze del server
  - [x] **Ricette** (sola lettura): elenco con ricerca, dettaglio con ingredienti/note/fonte
  - [x] **Inventario**: oggetti con ricerca, categoria/posizione, prezzo/garanzia e date tracciate;
        creazione, modifica (PUT completo) ed eliminazione con conferma
  - [x] **Dispensa**: scorte con quantità/unità, posizione, scadenza e scorta minima; creazione ed eliminazione
  - [x] **Note — categorie**: mostrate in lista, assegnabili dall'editor (`category_ids`) e gestibili
        (crea/rinomina/elimina, personali o condivise) dal dialog "Categorie"
  - [x] **Rifiuti**: prossima raccolta per tipo (countdown, data estesa, badge "spostato") nella tab
        "Prossime"; tab "Extra" con raccolte straordinarie creabili, modificabili ed eliminabili
        (tipo, data, nota)
  - [x] **Documenti**: metadati con ricerca, cartella, categoria, dimensione e autore; upload con
        selettore file (PDF, immagini, testo/CSV, Office → data URL base64) e archiviazione;
        download/anteprima restano sul web (richiedono la sessione)
  - [x] **Turni** (sola lettura): settimana lunedì–domenica con navigazione, turni per giorno
        (nome, orari, "+1" per la notte), riposi e nome/colore del membro
- [ ] Altri moduli su richiesta: statistiche budget estese (grafici), scritture mancanti
      (inventario, turni di raccolta, upload documenti), …
- [ ] (opzionale) PWA/web build: **non compatibile** con il supporto self-signed attuale
      (`dart:io` in `YuvomiApi`); richiederebbe un adapter condizionale con `kIsWeb`

## Fix script (fatti in M0)
1. **`update-openapi.sh`**: passo `build_runner` assente → risolto (dev deps + build.yaml)
2. **`update-openapi.sh`**: estrazione versione fragile → parse JSON con python3
3. **`update-openapi.sh`**: sanitizzazione spec per il generatore (`scripts/prep_spec.py`)
4. **`fetch-release.sh`**: guard + errore chiaro se la release non ha asset zip
5. **`scripts/.env`**: token in chiaro → non committato (fuori dal repo app/)
6. **Coerenza versioni**: omvnas deve essere sulla stessa versione della reference (documentato)
7. **AGENTS.md**: corretto naming `openapi.yaml` → `openapi.json` (già fatto)

## Rischi / note
- La spec ha 431 endpoint: il client generato sarà grande (~135 model + ~30 service);
  in MVP useremo solo gli endpoint dei 5 moduli + auth + dashboard.
- Endpoint senza pagination: verificare i query params durante M2 (es. task calendar range).
- 2FA: il login può richiedere un secondo step (`/auth/2fa/verify`) — gestito in M0 (screen 2FA).
- Auth: l'app usa **cookie session + X-CSRF-Token** (come il web), non Bearer.
  Il token Bearer si crea solo da admin, non è generalizzabile per un client.
- Connessione http/https: i server Yuvomi domestici sono spesso in **http** (LAN) —
  il blocco Android sul cleartext va gestito (vedi M0), altrimenti il login fallirebbe
  solo su Android mentre funzionerebbe su Windows/Linux.

## Domande aperte (non bloccanti)
1. Push su Android: FCM richiede setup server-side Yuvomi (verificare se il backend lo supporta)
   o ci si limita a polling dei reminder?
2. In M2, la vista calendar usa una libreria (es. `syncfree_flutter_package` / calendario custom)
   o si parte con una lista eventi per giorno senza libreria? (tendenza: lista semplice prima)
3. Nomi/icone delle tab della bottom bar: defaults Material, da rifinire nel design M1.
