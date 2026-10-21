# 🐾 SimplyPets — Modern Pet & Health Tracker

A modern, fast, zero-dependency web application to track multiple pets, their weights, medication schedules, and health records. Built with Python standard library, SQLite, and vanilla modern web technologies.

![SimplyPets Banner](static/favicon.svg)

---

## ✨ Features

- **👤 User Accounts & Private Pet Collections**:
  - Create an account or log in on a dedicated login page (`/login.html`).
  - Each user gets their own private set of pets, medications, weight logs, and stats.
  - Passwords are salted + hashed (PBKDF2-SHA256); API access uses per-session bearer tokens.
  - Pets created before accounts existed are adopted into the first account that signs up.

- **🐕 Multi-Pet Profiles**:
  - Add and manage multiple pets (Dogs, Cats, Rabbits, Birds, Hamsters, Reptiles, and more).
  - Track **Name, Species, Breed, Gender, Weight, Birthdate / Adoption Date**, Microchip ID, Vet & Clinic contact info, and special behavioral/dietary notes.
  - Upload **custom profile pictures** (JPEG, PNG, WebP, GIF, HEIF) with live circular preview, in-form photo management, and 1-tap photo updates in the pet record, with cute custom emoji avatar icons (🐶, 🐱, 🐰, 🦜, 🐹, 🐾) as fallbacks.
  - Instant live search by pet name, breed, or medication name (press `/` to search).
  - Filter by species and sort by name, weight, or medication count.

- **💊 Medication Management**:
  - Add multiple medications per pet with **Medication Name, Dosage (e.g. 16 mg, 1 tablet), Frequency (e.g. Once daily, Twice daily, Weekly, Monthly, As needed), Time of Day (Morning, Noon, Evening, Bedtime)**, Prescribing Vet, and special administration instructions (e.g. "Give with food").
  - Toggle between active and completed/historical prescriptions.
  - Edit or remove medications with instant updates.

- **📅 Daily Medication Checklist & Dose Tracker**:
  - Dedicated "Today's Meds Schedule" dashboard tab showing all doses due today across all pets.
  - 1-click **"Mark Dose Taken"** button with timestamped dose history logging.

- **📈 Weight Tracker & Progression Charts**:
  - Keep a timestamped record of weigh-ins over time.
  - Interactive zero-dependency responsive SVG progression chart showing weight curves, min/max points, and dates.
  - Automatic calculation of weight deltas (gain/loss relative to previous checkups).

- **🖨️ Vet & Pet-Sitter Care Sheets**:
  - Built-in print mode (`Ctrl+P` or click "Print Record") formatted cleanly for taking to vet appointments or leaving with pet sitters.

- **💾 Data Portability & Persistence**:
  - Persistent SQLite database (`pets.db`).
  - 1-click **"Load Sample Pets"** to explore with realistic demo pets (Luna the Golden Retriever, Milo the Tabby Cat, Barnaby the Lop Rabbit, Cleo the French Bulldog).
  - Complete JSON backup export and import to restore your data anytime.
  - 1-click database reset option.

- **🎨 Modern UI & Dark Mode**:
  - Clean, responsive card grid design that works on mobile, tablet, and desktop.
  - Automatic dark/light theme detection with manual toggle button.
  - Keyboard shortcuts (`/` to search, `N` for new pet, `Esc` to close modals).
  - Micro-animations and toast notifications.

---

## 🚀 Quick Start

### 1. Launch the Server

Simply run the launch script:
```bash
./start.sh
```
Or directly with Python 3:
```bash
python3 server.py
```

### 2. Open in Your Browser

Visit:
```
http://localhost:8080
```
*(If port 8080 is in use, the server automatically selects the next open port like 8081)*

### 3. Create Your Account

You'll land on the login page first. Choose **Create account**, pick a username and password (min. 6 characters), and you'll be taken to your own empty pet dashboard. Use **Load Sample Pets** to explore with demo data, or add your first pet directly.

---

## 🧪 Running the Test Suite

The project includes an automated test suite verifying database CRUD, REST API endpoints, static assets, demo/export flows, as well as a full Flutter unit & widget test suite:

### Python Backend & REST Tests:
```bash
python3 test_server.py
```

### Flutter Test Suite:
```bash
flutter test
```

### Flutter Static Analysis:
```bash
flutter analyze
```

---

## 📱 Flutter Application Architecture

The frontend is written in **Flutter** using the layered MVVM architecture (Data, Models, Repositories, UI Core, and Feature Views):

```
simply-pets/
├── lib/
│   ├── main.dart                          # App entry point, session & theme management
│   ├── data/
│   │   ├── models/                        # Domain & API models (User, Pet, Medication, WeightLog, Stats)
│   │   ├── repositories/                  # Repositories (Auth, Pet, Medication, Weight)
│   │   └── services/                      # ApiService (HTTP client, 401 guard) & StorageService (Prefs)
│   └── ui/
│       ├── core/
│       │   ├── constants.dart             # Species, avatars, frequencies, sort mappings
│       │   ├── theme.dart                 # Custom Material 3 theme (Light & Dark modes)
│       │   └── widgets/                   # AvatarBadge, StatCard, WeightChartWidget, CareSheetDialog, ConfirmDialog
│       └── features/
│           ├── auth/                      # Login & Sign up views with tab switching
│           ├── dashboard/                 # Responsive main dashboard, stats ribbon, pets grid, filters
│           ├── schedule/                  # Daily medication checklist & 1-click dose logger
│           ├── pet_detail/                # Full pet record dialog (Meds, Weight chart, Care sheet)
│           ├── pet_form/                  # Add / Edit pet dialog with avatar selector
│           ├── medication_form/           # Add / Edit medication prescription dialog
│           ├── weight_form/               # Record weight dialog with unit selection
│           └── export_backup/             # Backup JSON export, import, & reset database
├── test/
│   └── widget_test.dart                   # Unit & Widget tests for models, components, & app smoke test
├── web/                                   # Flutter web runner & index.html
├── server.py                              # Python HTTP server + REST API (serves Flutter web app)
├── database.py                            # SQLite connection, schema, and queries
├── test_server.py                         # Automated backend test suite
└── start.sh                               # Launch script
```

### Developing & Running with Flutter:

- **Run in Chrome (Development):**
  ```bash
  flutter run -d chrome
  ```
- **Run on Linux Desktop:**
  ```bash
  flutter run -d linux
  ```
- **Build Flutter Web for Production:**
  ```bash
  flutter build web --release
  ```
- **Launch with Backend Server:**
  ```bash
  ./start.sh
  ```

### REST API Endpoints

All `/api/*` endpoints except signup/login require an `Authorization: Bearer <token>` header from login or signup. Each user only sees their own pets.

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/api/auth/signup` | Create an account; returns `{user, token}` |
| `POST` | `/api/auth/login` | Log in; returns `{user, token}` |
| `POST` | `/api/auth/logout` | Invalidate the current session token |
| `GET` | `/api/auth/me` | Get the currently logged-in user |
| `GET` | `/api/pets` | List all pets with medication & weight counts |
| `POST` | `/api/pets` | Create a new pet (with optional initial med) |
| `GET` | `/api/pets/:id` | Get full pet profile, medications, & weight history |
| `PUT` | `/api/pets/:id` | Update pet details |
| `DELETE` | `/api/pets/:id` | Delete a pet and all associated logs |
| `POST` | `/api/pets/:id/medications` | Add a new medication for a pet |
| `PUT` | `/api/medications/:id` | Update medication details |
| `DELETE` | `/api/medications/:id` | Delete a medication |
| `POST` | `/api/medications/:id/dose` | Record a dose taken today |
| `GET` | `/api/medications/today` | List active medications scheduled for today |
| `POST` | `/api/pets/:id/weights` | Record a new weight entry |
| `DELETE` | `/api/weights/:id` | Remove a weight log entry |
| `GET` | `/api/stats` | Dashboard statistics (total pets, active meds, etc.) |
| `POST` | `/api/demo` | Seed sample pets and medications (replaces your pets) |
| `POST` | `/api/reset` | Clear all of your records |
| `GET` | `/api/export` | Export your pets as a JSON backup |
| `POST` | `/api/import` | Import pets and medications from JSON into your account |
