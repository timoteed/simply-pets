"""
Database module for SimplyPets web application.
Handles SQLite connection, schema migrations, and CRUD operations.
"""

import os
import sqlite3
import json
from datetime import datetime

DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "pets.db")

def get_db_connection(db_file=None):
    path = db_file or DB_PATH
    conn = sqlite3.connect(path)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn

def init_db(db_file=None):
    """Initialize database schema with tables and indexes."""
    conn = get_db_connection(db_file)
    with conn:
        conn.executescript("""
            CREATE TABLE IF NOT EXISTS pets (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                species TEXT NOT NULL DEFAULT 'Dog',
                breed TEXT NOT NULL DEFAULT '',
                birthdate TEXT DEFAULT '',
                gender TEXT DEFAULT 'Unknown',
                weight REAL NOT NULL DEFAULT 0.0,
                weight_unit TEXT NOT NULL DEFAULT 'lbs',
                avatar TEXT DEFAULT 'dog',
                microchip_id TEXT DEFAULT '',
                vet_info TEXT DEFAULT '',
                notes TEXT DEFAULT '',
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS medications (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                pet_id INTEGER NOT NULL,
                name TEXT NOT NULL,
                dosage TEXT NOT NULL DEFAULT '',
                frequency TEXT NOT NULL DEFAULT 'Once daily',
                time_of_day TEXT DEFAULT 'Morning',
                start_date TEXT DEFAULT '',
                end_date TEXT DEFAULT '',
                instructions TEXT DEFAULT '',
                prescribing_vet TEXT DEFAULT '',
                is_active INTEGER NOT NULL DEFAULT 1,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                FOREIGN KEY (pet_id) REFERENCES pets(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS weight_logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                pet_id INTEGER NOT NULL,
                weight REAL NOT NULL,
                weight_unit TEXT NOT NULL DEFAULT 'lbs',
                logged_date TEXT NOT NULL,
                notes TEXT DEFAULT '',
                created_at TEXT NOT NULL,
                FOREIGN KEY (pet_id) REFERENCES pets(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS dose_logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                medication_id INTEGER NOT NULL,
                pet_id INTEGER NOT NULL,
                given_at TEXT NOT NULL,
                notes TEXT DEFAULT '',
                FOREIGN KEY (medication_id) REFERENCES medications(id) ON DELETE CASCADE,
                FOREIGN KEY (pet_id) REFERENCES pets(id) ON DELETE CASCADE
            );

            CREATE INDEX IF NOT EXISTS idx_meds_pet_id ON medications(pet_id);
            CREATE INDEX IF NOT EXISTS idx_weights_pet_id ON weight_logs(pet_id);
            CREATE INDEX IF NOT EXISTS idx_doses_med_id ON dose_logs(medication_id);
        """)
    conn.close()

# ---------------- PET OPERATIONS ----------------

def get_all_pets(db_file=None):
    conn = get_db_connection(db_file)
    cursor = conn.cursor()
    cursor.execute("""
        SELECT p.*,
            (SELECT COUNT(*) FROM medications m WHERE m.pet_id = p.id AND m.is_active = 1) AS active_med_count,
            (SELECT COUNT(*) FROM medications m WHERE m.pet_id = p.id) AS total_med_count
        FROM pets p
        ORDER BY p.name COLLATE NOCASE ASC
    """)
    rows = [dict(row) for row in cursor.fetchall()]
    conn.close()
    return rows

def get_pet_by_id(pet_id, db_file=None):
    conn = get_db_connection(db_file)
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM pets WHERE id = ?", (pet_id,))
    pet_row = cursor.fetchone()
    if not pet_row:
        conn.close()
        return None
    
    pet = dict(pet_row)

    # Fetch medications
    cursor.execute("""
        SELECT m.*,
            (SELECT COUNT(*) FROM dose_logs d 
             WHERE d.medication_id = m.id 
             AND date(d.given_at) = date('now', 'localtime')) AS taken_today_count,
            (SELECT MAX(d.given_at) FROM dose_logs d WHERE d.medication_id = m.id) AS last_given_at
        FROM medications m
        WHERE m.pet_id = ?
        ORDER BY m.is_active DESC, m.name COLLATE NOCASE ASC
    """, (pet_id,))
    pet["medications"] = [dict(row) for row in cursor.fetchall()]

    # Fetch weight history
    cursor.execute("""
        SELECT * FROM weight_logs
        WHERE pet_id = ?
        ORDER BY logged_date ASC, id ASC
    """, (pet_id,))
    pet["weight_history"] = [dict(row) for row in cursor.fetchall()]

    conn.close()
    return pet

def create_pet(data, db_file=None):
    now = datetime.now().isoformat()
    name = (data.get("name") or "").strip()
    if not name:
        raise ValueError("Pet name is required")
    
    species = data.get("species", "Dog")
    breed = (data.get("breed") or "").strip()
    birthdate = data.get("birthdate", "")
    gender = data.get("gender", "Unknown")
    try:
        weight = float(data.get("weight", 0.0))
    except (ValueError, TypeError):
        weight = 0.0
    weight_unit = data.get("weight_unit", "lbs")
    avatar = data.get("avatar", "dog")
    microchip_id = (data.get("microchip_id") or "").strip()
    vet_info = (data.get("vet_info") or "").strip()
    notes = (data.get("notes") or "").strip()

    conn = get_db_connection(db_file)
    cursor = conn.cursor()
    with conn:
        cursor.execute("""
            INSERT INTO pets (
                name, species, breed, birthdate, gender, weight, weight_unit,
                avatar, microchip_id, vet_info, notes, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (name, species, breed, birthdate, gender, weight, weight_unit,
              avatar, microchip_id, vet_info, notes, now, now))
        pet_id = cursor.lastrowid

        # Also add initial weight log entry if weight > 0
        if weight > 0:
            cursor.execute("""
                INSERT INTO weight_logs (pet_id, weight, weight_unit, logged_date, notes, created_at)
                VALUES (?, ?, ?, ?, ?, ?)
            """, (pet_id, weight, weight_unit, now[:10], "Initial weight recorded", now))

        # Add initial medications if provided in creation payload
        medications = data.get("medications", [])
        if isinstance(medications, list):
            for med in medications:
                m_name = (med.get("name") or "").strip()
                if not m_name:
                    continue
                m_dosage = (med.get("dosage") or "").strip()
                m_freq = med.get("frequency", "Once daily")
                m_times = med.get("time_of_day", "Morning")
                m_start = med.get("start_date", now[:10])
                m_end = med.get("end_date", "")
                m_inst = (med.get("instructions") or "").strip()
                m_vet = (med.get("prescribing_vet") or "").strip()
                m_active = 1 if med.get("is_active", True) else 0

                cursor.execute("""
                    INSERT INTO medications (
                        pet_id, name, dosage, frequency, time_of_day,
                        start_date, end_date, instructions, prescribing_vet,
                        is_active, created_at, updated_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, (pet_id, m_name, m_dosage, m_freq, m_times,
                      m_start, m_end, m_inst, m_vet, m_active, now, now))

    conn.close()
    return get_pet_by_id(pet_id, db_file)

def update_pet(pet_id, data, db_file=None):
    now = datetime.now().isoformat()
    conn = get_db_connection(db_file)
    cursor = conn.cursor()

    cursor.execute("SELECT * FROM pets WHERE id = ?", (pet_id,))
    existing = cursor.fetchone()
    if not existing:
        conn.close()
        return None

    name = (data.get("name", existing["name"]) or "").strip()
    if not name:
        raise ValueError("Pet name cannot be blank")

    species = data.get("species", existing["species"])
    breed = (data.get("breed", existing["breed"]) or "").strip()
    birthdate = data.get("birthdate", existing["birthdate"])
    gender = data.get("gender", existing["gender"])
    try:
        new_weight = float(data.get("weight", existing["weight"]))
    except (ValueError, TypeError):
        new_weight = existing["weight"]
    weight_unit = data.get("weight_unit", existing["weight_unit"])
    avatar = data.get("avatar", existing["avatar"])
    microchip_id = (data.get("microchip_id", existing["microchip_id"]) or "").strip()
    vet_info = (data.get("vet_info", existing["vet_info"]) or "").strip()
    notes = (data.get("notes", existing["notes"]) or "").strip()

    with conn:
        cursor.execute("""
            UPDATE pets SET
                name = ?, species = ?, breed = ?, birthdate = ?, gender = ?,
                weight = ?, weight_unit = ?, avatar = ?, microchip_id = ?,
                vet_info = ?, notes = ?, updated_at = ?
            WHERE id = ?
        """, (name, species, breed, birthdate, gender, new_weight, weight_unit,
              avatar, microchip_id, vet_info, notes, now, pet_id))

        # If weight changed and logging requested or different from latest
        if "log_weight_change" in data and data["log_weight_change"] and new_weight != existing["weight"]:
            cursor.execute("""
                INSERT INTO weight_logs (pet_id, weight, weight_unit, logged_date, notes, created_at)
                VALUES (?, ?, ?, ?, ?, ?)
            """, (pet_id, new_weight, weight_unit, now[:10], "Updated from pet profile", now))

    conn.close()
    return get_pet_by_id(pet_id, db_file)

def delete_pet(pet_id, db_file=None):
    conn = get_db_connection(db_file)
    cursor = conn.cursor()
    with conn:
        cursor.execute("DELETE FROM pets WHERE id = ?", (pet_id,))
        deleted = cursor.rowcount > 0
    conn.close()
    return deleted

# ---------------- MEDICATION OPERATIONS ----------------

def add_medication(pet_id, data, db_file=None):
    now = datetime.now().isoformat()
    name = (data.get("name") or "").strip()
    if not name:
        raise ValueError("Medication name is required")

    dosage = (data.get("dosage") or "").strip()
    frequency = data.get("frequency", "Once daily")
    time_of_day = data.get("time_of_day", "Morning")
    start_date = data.get("start_date", now[:10])
    end_date = data.get("end_date", "")
    instructions = (data.get("instructions") or "").strip()
    prescribing_vet = (data.get("prescribing_vet") or "").strip()
    is_active = 1 if data.get("is_active", True) else 0

    conn = get_db_connection(db_file)
    cursor = conn.cursor()
    with conn:
        cursor.execute("""
            INSERT INTO medications (
                pet_id, name, dosage, frequency, time_of_day,
                start_date, end_date, instructions, prescribing_vet,
                is_active, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (pet_id, name, dosage, frequency, time_of_day,
              start_date, end_date, instructions, prescribing_vet,
              is_active, now, now))
        med_id = cursor.lastrowid
        cursor.execute("SELECT * FROM medications WHERE id = ?", (med_id,))
        med = dict(cursor.fetchone())
    conn.close()
    return med

def update_medication(med_id, data, db_file=None):
    now = datetime.now().isoformat()
    conn = get_db_connection(db_file)
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM medications WHERE id = ?", (med_id,))
    existing = cursor.fetchone()
    if not existing:
        conn.close()
        return None

    name = (data.get("name", existing["name"]) or "").strip()
    if not name:
        raise ValueError("Medication name cannot be blank")

    dosage = (data.get("dosage", existing["dosage"]) or "").strip()
    frequency = data.get("frequency", existing["frequency"])
    time_of_day = data.get("time_of_day", existing["time_of_day"])
    start_date = data.get("start_date", existing["start_date"])
    end_date = data.get("end_date", existing["end_date"])
    instructions = (data.get("instructions", existing["instructions"]) or "").strip()
    prescribing_vet = (data.get("prescribing_vet", existing["prescribing_vet"]) or "").strip()
    
    is_active_val = data.get("is_active", existing["is_active"])
    is_active = 1 if is_active_val in (1, True, "1", "true") else 0

    with conn:
        cursor.execute("""
            UPDATE medications SET
                name = ?, dosage = ?, frequency = ?, time_of_day = ?,
                start_date = ?, end_date = ?, instructions = ?,
                prescribing_vet = ?, is_active = ?, updated_at = ?
            WHERE id = ?
        """, (name, dosage, frequency, time_of_day,
              start_date, end_date, instructions,
              prescribing_vet, is_active, now, med_id))
        cursor.execute("SELECT * FROM medications WHERE id = ?", (med_id,))
        updated = dict(cursor.fetchone())
    conn.close()
    return updated

def delete_medication(med_id, db_file=None):
    conn = get_db_connection(db_file)
    cursor = conn.cursor()
    with conn:
        cursor.execute("DELETE FROM medications WHERE id = ?", (med_id,))
        deleted = cursor.rowcount > 0
    conn.close()
    return deleted

def log_dose(med_id, notes="", db_file=None):
    now = datetime.now().isoformat()
    conn = get_db_connection(db_file)
    cursor = conn.cursor()
    cursor.execute("SELECT pet_id FROM medications WHERE id = ?", (med_id,))
    row = cursor.fetchone()
    if not row:
        conn.close()
        return None
    pet_id = row["pet_id"]

    with conn:
        cursor.execute("""
            INSERT INTO dose_logs (medication_id, pet_id, given_at, notes)
            VALUES (?, ?, ?, ?)
        """, (med_id, pet_id, now, notes))
        dose_id = cursor.lastrowid
        cursor.execute("SELECT * FROM dose_logs WHERE id = ?", (dose_id,))
        dose = dict(cursor.fetchone())
    conn.close()
    return dose

def get_today_medications(db_file=None):
    """Retrieve all active medications across all pets along with whether dose was logged today."""
    conn = get_db_connection(db_file)
    cursor = conn.cursor()
    cursor.execute("""
        SELECT 
            m.*,
            p.name AS pet_name,
            p.species AS pet_species,
            p.avatar AS pet_avatar,
            (SELECT COUNT(*) FROM dose_logs d 
             WHERE d.medication_id = m.id 
             AND date(d.given_at) = date('now', 'localtime')) AS doses_given_today,
            (SELECT MAX(d.given_at) FROM dose_logs d WHERE d.medication_id = m.id) AS last_given_at
        FROM medications m
        JOIN pets p ON m.pet_id = p.id
        WHERE m.is_active = 1
        ORDER BY p.name COLLATE NOCASE ASC, m.name COLLATE NOCASE ASC
    """)
    rows = [dict(r) for r in cursor.fetchall()]
    conn.close()
    return rows

# ---------------- WEIGHT OPERATIONS ----------------

def add_weight_log(pet_id, weight, weight_unit="lbs", logged_date=None, notes="", db_file=None):
    now = datetime.now().isoformat()
    if not logged_date:
        logged_date = now[:10]
    try:
        w_val = float(weight)
    except (ValueError, TypeError):
        raise ValueError("Invalid weight value")

    conn = get_db_connection(db_file)
    cursor = conn.cursor()
    with conn:
        cursor.execute("""
            INSERT INTO weight_logs (pet_id, weight, weight_unit, logged_date, notes, created_at)
            VALUES (?, ?, ?, ?, ?, ?)
        """, (pet_id, w_val, weight_unit, logged_date, notes, now))
        log_id = cursor.lastrowid

        # Update current pet weight
        cursor.execute("""
            UPDATE pets SET weight = ?, weight_unit = ?, updated_at = ?
            WHERE id = ?
        """, (w_val, weight_unit, now, pet_id))

        cursor.execute("SELECT * FROM weight_logs WHERE id = ?", (log_id,))
        item = dict(cursor.fetchone())
    conn.close()
    return item

def delete_weight_log(log_id, db_file=None):
    conn = get_db_connection(db_file)
    cursor = conn.cursor()
    cursor.execute("SELECT pet_id FROM weight_logs WHERE id = ?", (log_id,))
    row = cursor.fetchone()
    if not row:
        conn.close()
        return False
    pet_id = row["pet_id"]

    with conn:
        cursor.execute("DELETE FROM weight_logs WHERE id = ?", (log_id,))
        # Update pet weight to the most recent entry if available
        cursor.execute("""
            SELECT weight, weight_unit FROM weight_logs
            WHERE pet_id = ?
            ORDER BY logged_date DESC, id DESC
            LIMIT 1
        """, (pet_id,))
        latest = cursor.fetchone()
        if latest:
            cursor.execute("""
                UPDATE pets SET weight = ?, weight_unit = ?, updated_at = ?
                WHERE id = ?
            """, (latest["weight"], latest["weight_unit"], datetime.now().isoformat(), pet_id))

    conn.close()
    return True

# ---------------- SUMMARY & STATS ----------------

def get_stats(db_file=None):
    conn = get_db_connection(db_file)
    cursor = conn.cursor()
    cursor.execute("SELECT COUNT(*) AS total_pets FROM pets")
    total_pets = cursor.fetchone()["total_pets"]

    cursor.execute("SELECT COUNT(*) AS active_meds FROM medications WHERE is_active = 1")
    active_meds = cursor.fetchone()["active_meds"]

    cursor.execute("""
        SELECT COUNT(DISTINCT medication_id) AS meds_taken_today
        FROM dose_logs
        WHERE date(given_at) = date('now', 'localtime')
    """)
    meds_taken_today = cursor.fetchone()["meds_taken_today"]

    conn.close()
    return {
        "total_pets": total_pets,
        "active_medications": active_meds,
        "meds_taken_today": meds_taken_today
    }

# ---------------- DEMO & RESET ----------------

def seed_demo_data(db_file=None):
    """Seed realistic and delightful sample pets and medications."""
    init_db(db_file)
    conn = get_db_connection(db_file)
    with conn:
        conn.execute("DELETE FROM dose_logs")
        conn.execute("DELETE FROM weight_logs")
        conn.execute("DELETE FROM medications")
        conn.execute("DELETE FROM pets")
    conn.close()

    pets = [
        {
            "name": "Luna",
            "species": "Dog",
            "breed": "Golden Retriever",
            "birthdate": "2021-04-12",
            "gender": "Spayed Female",
            "weight": 64.5,
            "weight_unit": "lbs",
            "avatar": "dog",
            "microchip_id": "985141002348123",
            "vet_info": "Dr. Sarah Adams • Oakwood Vet Clinic (555-0192)",
            "notes": "Loves tennis balls, allergic to chicken poultry meal. Very friendly with children.",
            "medications": [
                {
                    "name": "Apoquel",
                    "dosage": "16 mg",
                    "frequency": "Once daily",
                    "time_of_day": "Morning",
                    "instructions": "Give with peanut butter or pill pocket after breakfast for seasonal allergies.",
                    "prescribing_vet": "Dr. Sarah Adams",
                    "is_active": True
                },
                {
                    "name": "Heartgard Plus",
                    "dosage": "Chewable tablet (51-100 lbs)",
                    "frequency": "Monthly",
                    "time_of_day": "Morning",
                    "instructions": "Administer on the 1st of every month with food.",
                    "prescribing_vet": "Dr. Sarah Adams",
                    "is_active": True
                },
                {
                    "name": "Glucosamine Joint Supplement",
                    "dosage": "1 chew",
                    "frequency": "Twice daily",
                    "time_of_day": "Morning, Evening",
                    "instructions": "Support for hip & joint mobility.",
                    "prescribing_vet": "Dr. Sarah Adams",
                    "is_active": True
                }
            ]
        },
        {
            "name": "Milo",
            "species": "Cat",
            "breed": "Domestic Shorthair (Orange Tabby)",
            "birthdate": "2020-08-19",
            "gender": "Neutered Male",
            "weight": 11.2,
            "weight_unit": "lbs",
            "avatar": "cat",
            "microchip_id": "985141009941029",
            "vet_info": "Cat Care Hospital • Dr. Marcus Chen (555-0144)",
            "notes": "Indoor cat only. Microchipped. Very affectionate purr machine.",
            "medications": [
                {
                    "name": "Felimazole",
                    "dosage": "2.5 mg",
                    "frequency": "Twice daily",
                    "time_of_day": "Morning, Evening",
                    "instructions": "Every 12 hours with wet food for thyroid management.",
                    "prescribing_vet": "Dr. Marcus Chen",
                    "is_active": True
                }
            ]
        },
        {
            "name": "Barnaby",
            "species": "Rabbit",
            "breed": "Holland Lop",
            "birthdate": "2023-01-10",
            "gender": "Neutered Male",
            "weight": 3.8,
            "weight_unit": "lbs",
            "avatar": "rabbit",
            "microchip_id": "",
            "vet_info": "Exotic Pets Practice • Dr. Elena Rios (555-0188)",
            "notes": "Loves fresh Timothy hay and cilantro. Check ears regularly.",
            "medications": [
                {
                    "name": "Metacam (Meloxicam)",
                    "dosage": "0.3 ml oral suspension",
                    "frequency": "Once daily",
                    "time_of_day": "Evening",
                    "instructions": "Give directly via oral syringe after dinner for mild hock arthritis.",
                    "prescribing_vet": "Dr. Elena Rios",
                    "is_active": True
                }
            ]
        },
        {
            "name": "Cleo",
            "species": "Dog",
            "breed": "French Bulldog",
            "birthdate": "2022-11-05",
            "gender": "Spayed Female",
            "weight": 22.0,
            "weight_unit": "lbs",
            "avatar": "dog",
            "microchip_id": "985141003492817",
            "vet_info": "Dr. Sarah Adams • Oakwood Vet Clinic (555-0192)",
            "notes": "Brachycephalic breed - monitor breathing in warm weather. Sensitive stomach.",
            "medications": [
                {
                    "name": "NexGard Spectra",
                    "dosage": "1 chewable",
                    "frequency": "Monthly",
                    "time_of_day": "Morning",
                    "instructions": "Flea and tick prevention. Give first Sunday of month.",
                    "prescribing_vet": "Dr. Sarah Adams",
                    "is_active": True
                }
            ]
        }
    ]

    # Create pets and extra weight logs
    for p_data in pets:
        pet = create_pet(p_data, db_file)
        # Add past weight logs to show trend chart
        p_id = pet["id"]
        w = pet["weight"]
        u = pet["weight_unit"]
        # Add 3 historical points
        add_weight_log(p_id, round(w - 1.2, 1), u, "2026-03-15", "Routine spring checkup", db_file)
        add_weight_log(p_id, round(w - 0.4, 1), u, "2026-06-20", "Mid-year check", db_file)
        add_weight_log(p_id, w, u, "2026-09-10", "Annual wellness exam", db_file)

    # Log today's dose for Luna's first medication
    pets_list = get_all_pets(db_file)
    if pets_list:
        luna = get_pet_by_id(pets_list[0]["id"], db_file)
        if luna and luna["medications"]:
            log_dose(luna["medications"][0]["id"], "Given with morning meal", db_file)

    return get_all_pets(db_file)

def reset_all_data(db_file=None):
    conn = get_db_connection(db_file)
    with conn:
        conn.execute("DELETE FROM dose_logs")
        conn.execute("DELETE FROM weight_logs")
        conn.execute("DELETE FROM medications")
        conn.execute("DELETE FROM pets")
    conn.close()

def export_all_data(db_file=None):
    pets = get_all_pets(db_file)
    full_pets = []
    for p in pets:
        full_pets.append(get_pet_by_id(p["id"], db_file))
    return {
        "version": "1.0",
        "exported_at": datetime.now().isoformat(),
        "pets": full_pets
    }

def import_all_data(data, db_file=None):
    if not isinstance(data, dict) or "pets" not in data:
        raise ValueError("Invalid import payload: missing 'pets' array")
    
    count = 0
    for p in data["pets"]:
        create_pet(p, db_file)
        count += 1
    return count
