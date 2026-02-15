# PDRRMO First Responder Dispatch App — Copilot Instructions

## Architecture Overview

Flutter mobile app (SDK ≥3.0) for Surigao Del Norte PDRRMO first responders. State management via **Provider** (`ChangeNotifier`). Networking via **Dio**. Routing via **go_router** (flat, no shell routes). Backend is a **Laravel API** with Sanctum bearer-token auth at `https://sdnpdrrmo.inno.ph/api/`.

### Active Code Path (the one `main.dart` actually uses)

```
main.dart → builds DI inline (SharedPreferences → ApiClient → AuthRemoteDataSource → AuthRepository → UseCases → Providers)
         → MultiProvider [AuthProvider, IncidentProvider]
         → App (app.dart) → GoRouter with auth redirect
```

### Dormant Code (exists but NOT wired into the running app)

- `injection_container.dart` — GetIt service locator (never called)
- `routes/app_router.dart` — alternative GoRouter with dispatch/role routes
- `core/network/dio_interceptor.dart` — FlutterSecureStorage-based interceptor
- `core/storage/token_storage.dart` — secure storage (unused)
- `core/providers/auth_provider.dart` — older auth provider at core level
- `features/dispatch/` — full clean-arch dispatch feature
- `features/dashboard/presentation/` — role-based dashboard screens

**Do not modify dormant files** unless explicitly asked. The active auth provider is at `features/auth/presentation/providers/auth_provider.dart`.

## Key Data Patterns

### Incidents use raw Maps, NOT typed models

`IncidentProvider` stores incidents as `List<Map<String, dynamic>>`. The typed `Incident` model in `core/models/incident.dart` exists but is **not used** by the provider or screens. Always access incident fields via map lookups:

```dart
// CORRECT — use .toString() or ?.toString() for null safety
final type = (incident['incident_type'] ?? incident['type'] ?? 'Unknown').toString();
final status = (incident['status'] ?? 'unknown').toString();
final severity = incident['severity']?.toString() ?? '';

// WRONG — never use `as String` casts on API map values
final type = incident['incident_type'] as String;  // CRASHES if null or int
```

### API field name mismatches

The API returns `incident_title` but some code expects `title`. Always check both:
```dart
final title = incident['title']?.toString() ?? incident['incident_title']?.toString() ?? 'Untitled';
```

### User entity

`User` (at `features/auth/domain/entities/user.dart`) has:
- `name` (String), `position` (String?), `division` (String?), `roles` (List\<String>)
- `roleLabel` → **non-nullable** String getter (returns first role or `'Staff'`)
- Access via `context.read<AuthProvider>().user` — can be null if not logged in

## Project Structure

```
lib/
├── main.dart                          # Entry point, inline DI wiring
├── app.dart                           # MaterialApp.router + GoRouter + routes
├── core/
│   ├── constants/                     # AppColors, ApiConstants, AppSizes, etc.
│   ├── models/                        # json_serializable models (mostly unused)
│   ├── network/api_client.dart        # Active Dio HTTP wrapper
│   ├── providers/incident_provider.dart  # Incident state (Maps, not models)
│   └── services/                      # ApiService, AuthService, LocationService
├── features/
│   ├── auth/                          # Clean architecture (data/domain/presentation)
│   ├── incidents/screens/             # List, detail, create, analytics (ACTIVE)
│   ├── incident/screens/              # Older detail screen (partially active)
│   ├── dashboard/screens/             # Dashboard (ACTIVE)
│   ├── map/screens/                   # Live map with flutter_map/OSM
│   ├── profile/screens/               # Profile screen
│   └── injury_mapper/                 # Body diagram annotation feature
```

## Conventions

- **Colors**: Use `AppColors` constants from `core/constants/app_colors.dart`. Severity/status colors via `AppColors.incidentSeverityColor(severity)` and `AppColors.incidentStatusColor(status)`.
- **Routing**: Navigate with `context.go('/incidents')` or `context.push('/incidents/$id')`. Routes defined in `app.dart`, NOT `routes/app_router.dart`.
- **State access**: `context.read<IncidentProvider>()` for actions, `context.watch<IncidentProvider>()` in build methods.
- **Error handling in providers**: Use `_errorMessage` string field, check in UI via `provider.errorMessage`.
- **Time display**: Use `timeago` package for relative timestamps, wrapped in try/catch for parse safety.
- **API calls**: Go through `ApiClient` (injected via constructor). Base URL + endpoints defined in `ApiConstants`.

## Build & Run

```bash
cd rlsb-dispatch-app
flutter run -d <device-id>                    # Run on device
flutter build apk --target-platform android-arm64 --split-per-abi  # Release APK
dart run build_runner build                   # Regenerate .g.dart files (if models change)
```

## Common Pitfalls

1. **Null safety with API data**: API fields can be `null`, `int`, or absent. Always use `?.toString()` instead of `as String` casts. Never use `!` on API-derived values.
2. **Two of everything**: Two auth providers, two routers, two HTTP clients, two incident detail screens exist. Only modify files imported by `main.dart` → `app.dart` unless consolidating.
3. **Auto-refresh**: `IncidentProvider` has a 30-second auto-refresh timer. Account for this when debugging — data may change between frames.
4. **Statistics are local**: No server stats endpoint. `fetchStatistics()` computes counts from the locally fetched incident list.
5. **Verbose logging**: `IncidentProvider` emits detailed emoji-tagged debug logs. These are intentional for field debugging on devices — don't remove them.
