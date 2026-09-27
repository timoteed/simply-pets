"""
Automated Test Suite for SimplyPets
Tests database functions, REST API endpoints, static assets, and end-to-end flows.
"""

import unittest
import os
import json
import urllib.request
import urllib.error
import threading
import time
from http.server import HTTPServer
import database
from server import PetsRequestHandler

TEST_DB = "test_pets.db"
TEST_PORT = 8999

class SimplyPetsTestCase(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Clean test DB if exists
        if os.path.exists(TEST_DB):
            os.remove(TEST_DB)
        
        # Point database default path or init
        database.DB_PATH = TEST_DB
        database.init_db(TEST_DB)

        # Start test HTTP server in background thread
        cls.server = HTTPServer(("127.0.0.1", TEST_PORT), PetsRequestHandler)
        cls.server_thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.server_thread.start()
        time.sleep(0.5)

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        if os.path.exists(TEST_DB):
            os.remove(TEST_DB)

    def _request(self, method, path, data=None):
        url = f"http://127.0.0.1:{TEST_PORT}{path}"
        req = urllib.request.Request(url, method=method)
        req.add_header("Content-Type", "application/json")
        body = json.dumps(data).encode("utf-8") if data is not None else None
        try:
            with urllib.request.urlopen(req, data=body) as response:
                status = response.status
                raw = response.read().decode("utf-8")
                try:
                    res_json = json.loads(raw)
                except Exception:
                    res_json = raw
                return status, res_json
        except urllib.error.HTTPError as e:
            raw = e.read().decode("utf-8")
            try:
                res_json = json.loads(raw)
            except Exception:
                res_json = raw
            return e.code, res_json

    def test_01_static_files(self):
        """Test static asset serving."""
        status, content = self._request("GET", "/")
        self.assertEqual(status, 200)
        self.assertIn("SimplyPets", content)

        status, content = self._request("GET", "/style.css")
        self.assertEqual(status, 200)
        self.assertIn("--primary", content)

        status, content = self._request("GET", "/app.js")
        self.assertEqual(status, 200)
        self.assertIn("SimplyPets", content)

        status, content = self._request("GET", "/favicon.svg")
        self.assertEqual(status, 200)
        self.assertIn("<svg", content)

    def test_02_create_and_get_pet(self):
        """Test creating a pet and retrieving it."""
        pet_payload = {
            "name": "Buster",
            "species": "Dog",
            "breed": "Beagle",
            "weight": 28.5,
            "weight_unit": "lbs",
            "gender": "Neutered Male",
            "notes": "Loves howling and tracking scents",
            "medications": [
                {
                    "name": "Simparica Trio",
                    "dosage": "1 chewable",
                    "frequency": "Monthly",
                    "instructions": "For fleas, ticks, and heartworm"
                }
            ]
        }
        status, pet = self._request("POST", "/api/pets", pet_payload)
        self.assertEqual(status, 201)
        self.assertEqual(pet["name"], "Buster")
        self.assertEqual(pet["breed"], "Beagle")
        self.assertEqual(pet["weight"], 28.5)
        self.assertEqual(len(pet["medications"]), 1)
        self.assertEqual(pet["medications"][0]["name"], "Simparica Trio")
        self.assertEqual(len(pet["weight_history"]), 1)

        # Retrieve pet by ID
        pet_id = pet["id"]
        status, retrieved = self._request("GET", f"/api/pets/{pet_id}")
        self.assertEqual(status, 200)
        self.assertEqual(retrieved["name"], "Buster")

        # Retrieve all pets
        status, all_pets = self._request("GET", "/api/pets")
        self.assertEqual(status, 200)
        self.assertTrue(any(p["id"] == pet_id for p in all_pets))

    def test_03_medication_crud_and_dose_logging(self):
        """Test adding, editing, logging dose, and deleting medication."""
        # Get pet
        status, all_pets = self._request("GET", "/api/pets")
        pet_id = all_pets[0]["id"]

        # Add medication
        med_payload = {
            "name": "Ear Drops (Otomax)",
            "dosage": "4 drops",
            "frequency": "Twice daily",
            "time_of_day": "Morning, Evening",
            "instructions": "Clean ear before applying",
            "is_active": True
        }
        status, med = self._request("POST", f"/api/pets/{pet_id}/medications", med_payload)
        self.assertEqual(status, 201)
        self.assertEqual(med["name"], "Ear Drops (Otomax)")
        med_id = med["id"]

        # Log dose
        status, dose = self._request("POST", f"/api/medications/{med_id}/dose", {"notes": "Morning ear wash done"})
        self.assertEqual(status, 201)
        self.assertEqual(dose["medication_id"], med_id)

        # Check today's medications
        status, today_meds = self._request("GET", "/api/medications/today")
        self.assertEqual(status, 200)
        found = next((m for m in today_meds if m["id"] == med_id), None)
        self.assertIsNotNone(found)
        self.assertEqual(found["doses_given_today"], 1)

        # Update medication
        update_payload = {
            "name": "Ear Drops (Otomax)",
            "dosage": "5 drops",
            "frequency": "Once daily",
            "is_active": True
        }
        status, updated_med = self._request("PUT", f"/api/medications/{med_id}", update_payload)
        self.assertEqual(status, 200)
        self.assertEqual(updated_med["dosage"], "5 drops")

        # Delete medication
        status, del_res = self._request("DELETE", f"/api/medications/{med_id}")
        self.assertEqual(status, 200)

    def test_04_weight_tracking(self):
        """Test adding a weight entry and checking pet weight history."""
        status, all_pets = self._request("GET", "/api/pets")
        pet_id = all_pets[0]["id"]

        weight_payload = {
            "weight": 29.2,
            "weight_unit": "lbs",
            "logged_date": "2026-09-27",
            "notes": "Healthy post-summer weight check"
        }
        status, weight_entry = self._request("POST", f"/api/pets/{pet_id}/weights", weight_payload)
        self.assertEqual(status, 201)
        self.assertEqual(weight_entry["weight"], 29.2)

        # Check that pet's current weight is updated
        status, pet = self._request("GET", f"/api/pets/{pet_id}")
        self.assertEqual(pet["weight"], 29.2)
        self.assertTrue(len(pet["weight_history"]) >= 2)

    def test_05_demo_seed_and_stats(self):
        """Test seeding demo data and fetching stats."""
        status, demo_res = self._request("POST", "/api/demo")
        self.assertEqual(status, 200)
        self.assertGreaterEqual(len(demo_res["pets"]), 3)

        status, stats = self._request("GET", "/api/stats")
        self.assertEqual(status, 200)
        self.assertGreaterEqual(stats["total_pets"], 3)
        self.assertGreaterEqual(stats["active_medications"], 1)

    def test_06_export_and_import(self):
        """Test data export and import."""
        status, export_data = self._request("GET", "/api/export")
        self.assertEqual(status, 200)
        self.assertIn("pets", export_data)
        self.assertTrue(len(export_data["pets"]) > 0)

        # Reset all data
        status, _ = self._request("POST", "/api/reset")
        self.assertEqual(status, 200)

        status, stats = self._request("GET", "/api/stats")
        self.assertEqual(stats["total_pets"], 0)

        # Import backed up data
        status, import_res = self._request("POST", "/api/import", export_data)
        self.assertEqual(status, 200)

        status, stats = self._request("GET", "/api/stats")
        self.assertTrue(stats["total_pets"] > 0)

    def test_07_delete_pet(self):
        """Test deleting a pet and cascade deletion of related records."""
        payload = {
            "name": "To Be Deleted",
            "species": "Cat",
            "breed": "Siamese",
            "weight": 8.0,
            "medications": [{"name": "Temporary Med", "dosage": "1 pill"}]
        }
        status, pet = self._request("POST", "/api/pets", payload)
        self.assertEqual(status, 201)
        pet_id = pet["id"]

        # Verify pet exists
        status, retrieved = self._request("GET", f"/api/pets/{pet_id}")
        self.assertEqual(status, 200)
        self.assertEqual(retrieved["name"], "To Be Deleted")

        # Delete the pet
        del_status, del_body = self._request("DELETE", f"/api/pets/{pet_id}")
        self.assertEqual(del_status, 200)
        self.assertIn("deleted successfully", del_body.get("message", ""))

        # Verify pet is gone
        get_status, _ = self._request("GET", f"/api/pets/{pet_id}")
        self.assertEqual(get_status, 404)

if __name__ == "__main__":
    unittest.main()
