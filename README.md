# CareFind

Find hospitals, clinics, pharmacies, labs, and dispensaries near you — powered by **OpenStreetMap**, with no Google Maps API key required.

CareFind uses a **dual-database architecture**: one SQLite database caches medical facilities from OSM, and a second stores user accounts, favorites, reviews, and emergency contacts.

| Database | File | Purpose |
|----------|------|---------|
| Hospital DB | `carefind_hospitals.db` | Cached OSM data + admin-enriched fields (specialities, services, ICU, verified flag, etc.) |
| User DB | `carefind_users.db` | Accounts, favorites, reviews, emergency contacts |

---

## Features

### Discovery & search

- **Nearby tab** — facilities around your location, ranked with major hospitals (Apollo, Fortis, AIIMS, etc.) listed first
- **Expanding-radius search** — starts at 7 km and grows through 15 → 25 → 50 → 100 → **150 km** until enough results are found
- **Category filters** — Hospitals, Clinics, Pharmacy, Labs, Dispensary  
  When few results exist nearby, the app automatically searches farther (up to 150 km) until it finds pharmacies, clinics, or other selected types
- **Name search** — type-ahead suggestions while you search (e.g. Manipal, Apollo)
- **Speciality & emergency filters** — Cardiology, Neurology, Orthopedics, and more; emergency-only toggle
- **Search India tab** — nationwide search via Nominatim; shows prominent nearby hospitals when the query is empty

### Maps & directions

- Interactive map with **OpenStreetMap** tiles (`flutter_map`)
- Turn-by-turn route preview via **OSRM** (driving directions from your location)
- Tap a facility to focus it on the map or open directions

### Facility details

- Address, category, distance, ratings, specialities, services, opening hours
- **Call now** — fetches phone numbers from OpenStreetMap when missing locally (`phone`, `contact:phone`, `contact:mobile`, etc.) and opens the device dialer
- Directions button with route loading on the map tab
- User reviews (sign-in required)

### Emergency

- Red **EMERGENCY** FAB on the home screen
- Call **112** (India) or a saved personal contact
- Pre-filled **SMS** to emergency contacts with your location link
- Emergency Mode screen lists nearby ER-capable facilities
- Emergency contacts and call preference stored locally (works for guests; syncs when logged in)

### Accounts & admin

- **Guest mode** — browse, search, and use emergency features without an account
- **Sign in** — favorites and reviews tied to your account
- **Admin panel** (Profile → Admin Panel, admin account only) — enrich hospital records in the Hospital DB

### Location

- Location requested on every app open (splash screen)
- Last known GPS saved and reused when live location is unavailable
- Home screen refreshes location when the app resumes

---

## OpenStreetMap stack

| Feature | Service |
|---------|---------|
| Map tiles | [OpenStreetMap](https://www.openstreetmap.org/) via `flutter_map` |
| Nearby & category search | [Overpass API](https://wiki.openstreetmap.org/wiki/Overpass_API) |
| Global search / geocoding | [Nominatim](https://nominatim.org/release-docs/latest/api/Search/) |
| Driving directions | [OSRM](https://router.project-osrm.org) |

No API keys are required. Use a descriptive `User-Agent` and respect [Nominatim usage policy](https://operations.osmfoundation.org/policies/nominatim/) (max 1 request/sec for public instances).

---

## Getting started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart ^3.7)
- Android Studio / Xcode for mobile, or Chrome for web
- On **Windows**, enable **Developer Mode** for symlink support (`flutter run` will prompt if needed)

### Install & run

```bash
cd carefind
flutter pub get
flutter run
```

### Run on Android emulator

```bash
flutter emulators --launch Pixel_3   # or your AVD name
flutter devices
flutter run -d emulator-5554
```

---

## Configuration

Pass overrides at build/run time with `--dart-define`:

```bash
# Demo mode — sample hospitals, no OSM network calls
flutter run --dart-define=DEMO_MODE=true

# Admin credentials (change in production)
flutter run \
  --dart-define=ADMIN_ID=admin \
  --dart-define=ADMIN_PASSWORD=your_secure_password

# Custom OSM / routing endpoints
flutter run \
  --dart-define=OSM_USER_AGENT=CareFind/1.0 \
  --dart-define=OVERPASS_API_URL=https://overpass-api.de/api/interpreter \
  --dart-define=NOMINATIM_API_URL=https://nominatim.openstreetmap.org \
  --dart-define=OSRM_API_URL=https://router.project-osrm.org
```

### Search radius defaults

Defined in `lib/config/app_config.dart`:

| Setting | Default | Description |
|---------|---------|-------------|
| `defaultSearchRadiusKm` | 7 km | Initial nearby search |
| `searchRadiusStepsKm` | 7, 15, 25, 50, 100, 150 | Expansion steps |
| `maxSearchRadiusKm` | 150 km | Maximum search distance |
| `minCategoryResults` | 5 | Minimum results before stopping category expansion |
| `targetNearbyHospitals` | 20 | Cap on displayed nearby results |

---

## Admin access

| Field | Default |
|-------|---------|
| Admin ID | `admin` |
| Password | `admin123` |

After signing in as admin, open **Profile → Admin Panel** to edit cached hospitals (specialities, services, verified status, etc.).

---

## Project structure

```
lib/
  config/       app_config.dart — radii, OSM URLs, admin defaults
  screens/      splash, login, register, home, hospital detail, emergency, settings, admin
  widgets/      nearby/map/favorites/profile tabs, hospital_card, emergency_trigger
  providers/    auth_provider, hospital_provider
  data/
    models/     hospital, review, user, filters, map mode, route
    database/   hospital_database, user_database
    repositories/  hospital, user, emergency
    services/   osm_places_service, routing_service
  core/
    database/   platform-specific SQLite init (mobile / web)
    services/   emergency_service (call + SMS)
    theme/      app_theme
    utils/      location, phone launcher, distance, permissions, network
```

---

## Permissions (Android)

Declared in `android/app/src/main/AndroidManifest.xml`:

- **Location** — nearby search and directions
- **Phone (`tel:`)** — Call now on facility details and emergency dial
- **SMS** — emergency message to contacts

---

## Build for release

```bash
# Android App Bundle (Play Store)
flutter build appbundle --release

# APK
flutter build apk --release
```

### Play Store checklist

- [Google Play Console](https://play.google.com/console) account ($25 one-time)
- Signed AAB with **Play App Signing**
- Privacy policy covering location, accounts, and OSM data
- Data Safety form completed
- Screenshots, icon, feature graphic
- OpenStreetMap attribution (shown on the map tab)

---

## Tech stack

| Layer | Packages |
|-------|----------|
| UI | Flutter, Material 3 |
| State | `provider` |
| Local storage | `sqflite`, `shared_preferences` |
| Maps | `flutter_map`, `latlong2` |
| Location | `geolocator`, `permission_handler` |
| Network | `http`, `connectivity_plus` |
| Deep links | `url_launcher` (phone, SMS) |

---

## License & attribution

Facility data © [OpenStreetMap contributors](https://www.openstreetmap.org/copyright), available under the [ODbL](https://opendatacommons.org/licenses/odbl/).

---

## Roadmap

- Firebase Auth + Firestore for cloud user sync
- PostgreSQL + PostGIS backend for curated hospital master data
- Self-hosted Nominatim / Overpass for production-scale traffic
- Push notifications for emergency contact alerts
