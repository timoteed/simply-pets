# 🐾 SimplyPets — Modern Pet & Health Tracker

A modern, fast, zero-dependency web application to track multiple pets, their weights, medication schedules, and health records. Built with Python standard library, SQLite, and vanilla modern web technologies.

![SimplyPets Banner](static/favicon.svg)

---

## ✨ Features

- **🐕 Multi-Pet Profiles**:
  - Add and manage multiple pets (Dogs, Cats, Rabbits, Birds, Hamsters, Reptiles, and more).
  - Track **Name, Species, Breed, Gender, Weight, Birthdate / Adoption Date**, Microchip ID, Vet & Clinic contact info, and special behavioral/dietary notes.
  - Choose from cute custom avatar icons (🐶, 🐱, 🐰, 🦜, 🐹, 🐾).
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

---

## 🧪 Running the Test Suite

The project includes an automated test suite verifying database CRUD, REST API endpoints, static assets, and demo/export flows:

```bash
python3 test_server.py
```

---

## 🏗️ Architecture & File Structure

```
simply-pets/
├── server.py             # Python HTTP server + REST API handlers
├── database.py           # SQLite connection, schema, and queries
├── test_server.py        # Automated test suite (6 passing test suites)
├── start.sh              # One-click launch script
├── README.md             # Project documentation
├── pets.db               # SQLite database file (created on launch)
└── static/
    ├── index.html        # Semantic HTML5 Single Page Application
    ├── style.css         # Modern design system & themes (Light / Dark)
    ├── app.js            # Frontend logic, state, and SVG charts
    └── favicon.svg       # SVG paw icon
```

### REST API Endpoints

| Method | Endpoint | Description |
|---|---|---|
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
| `POST` | `/api/demo` | Seed sample pets and medications |
| `POST` | `/api/reset` | Clear all records |
| `GET` | `/api/export` | Export full database as JSON |
| `POST` | `/api/import` | Import pets and medications from JSON |
