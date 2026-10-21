"""
Automated Test Suite for SimplyPets
Tests database functions, REST API endpoints, static assets, and end-to-end flows.
"""

import unittest
import os
import json
import sqlite3
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

        # Create the primary test user; its token is used by default in _request
        cls.auth_token = cls._raw_request(
            "POST", "/api/auth/signup",
            {"username": "testowner", "password": "testpass123", "display_name": "Test Owner"},
        )[1]["token"]

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        if os.path.exists(TEST_DB):
            os.remove(TEST_DB)

    @classmethod
    def _raw_request(cls, method, path, data=None, token=None):
        url = f"http://127.0.0.1:{TEST_PORT}{path}"
        req = urllib.request.Request(url, method=method)
        req.add_header("Content-Type", "application/json")
        if token:
            req.add_header("Authorization", f"Bearer {token}")
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

    def _request(self, method, path, data=None, token="default"):
        """Authenticated request; pass token=None for an unauthenticated call."""
        if token == "default":
            token = self.auth_token
        return self._raw_request(method, path, data, token)

    @classmethod
    def _multipart_upload(cls, path, filename, file_bytes, content_type="image/png", token=None):
        url = f"http://127.0.0.1:{TEST_PORT}{path}"
        boundary = "----SimplyPetsBoundaryXYZ"
        body = (
            f"--{boundary}\r\n"
            f'Content-Disposition: form-data; name="photo"; filename="{filename}"\r\n'
            f"Content-Type: {content_type}\r\n\r\n"
        ).encode("utf-8") + file_bytes + f"\r\n--{boundary}--\r\n".encode("utf-8")

        req = urllib.request.Request(url, data=body, method="POST")
        req.add_header("Content-Type", f"multipart/form-data; boundary={boundary}")
        if token:
            req.add_header("Authorization", f"Bearer {token}")
        try:
            with urllib.request.urlopen(req) as response:
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

    def test_00_auth_flows(self):
        """Test signup, login, session, logout, and unauthenticated access."""
        # Signup validation
        status, body = self._request("POST", "/api/auth/signup",
                                     {"username": "ab", "password": "longenough"}, token=None)
        self.assertEqual(status, 400)

        status, body = self._request("POST", "/api/auth/signup",
                                     {"username": "newuser", "password": "short"}, token=None)
        self.assertEqual(status, 400)

        # Successful signup returns user + token
        status, body = self._request("POST", "/api/auth/signup",
                                     {"username": "authuser", "password": "authpass123"}, token=None)
        self.assertEqual(status, 201)
        self.assertEqual(body["user"]["username"], "authuser")
        self.assertNotIn("password_hash", body["user"])
        signup_token = body["token"]

        # Duplicate username (case-insensitive) is rejected
        status, body = self._request("POST", "/api/auth/signup",
                                     {"username": "AuthUser", "password": "otherpass123"}, token=None)
        self.assertEqual(status, 409)

        # Login with wrong password fails
        status, body = self._request("POST", "/api/auth/login",
                                     {"username": "authuser", "password": "wrongpass"}, token=None)
        self.assertEqual(status, 401)

        # Login succeeds and session identifies the user
        status, body = self._request("POST", "/api/auth/login",
                                     {"username": "authuser", "password": "authpass123"}, token=None)
        self.assertEqual(status, 200)
        login_token = body["token"]
        status, me = self._request("GET", "/api/auth/me", token=login_token)
        self.assertEqual(status, 200)
        self.assertEqual(me["username"], "authuser")

        # Unauthenticated pet access is rejected
        status, body = self._request("GET", "/api/pets", token=None)
        self.assertEqual(status, 401)
        status, body = self._request("POST", "/api/pets", {"name": "Nope"}, token=None)
        self.assertEqual(status, 401)

        # Logout invalidates the token
        status, _ = self._request("POST", "/api/auth/logout", {}, token=signup_token)
        self.assertEqual(status, 200)
        status, _ = self._request("GET", "/api/auth/me", token=signup_token)
        self.assertEqual(status, 401)

    def test_01_static_files(self):
        """Test static asset serving."""
        status, content = self._request("GET", "/")
        self.assertEqual(status, 200)
        self.assertIn("SimplyPets", content)

        status, content = self._request("GET", "/login.html", token=None)
        self.assertEqual(status, 200)
        self.assertIn("Create account", content)

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

    def test_08_data_isolation_between_users(self):
        """Test that each user only sees and mutates their own pets."""
        # Primary user creates a pet with a medication
        status, pet = self._request("POST", "/api/pets", {
            "name": "Isolation Pup",
            "species": "Dog",
            "breed": "Poodle",
            "weight": 15.0,
            "medications": [{"name": "Private Med", "dosage": "1 pill"}],
        })
        self.assertEqual(status, 201)
        pet_id = pet["id"]
        med_id = pet["medications"][0]["id"]

        # Second user signs up with a fresh token
        status, body = self._request("POST", "/api/auth/signup",
                                     {"username": "seconduser", "password": "secondpass123"},
                                     token=None)
        self.assertEqual(status, 201)
        other_token = body["token"]

        # Second user sees none of the first user's data
        status, other_pets = self._request("GET", "/api/pets", token=other_token)
        self.assertEqual(status, 200)
        self.assertEqual(other_pets, [])
        status, other_stats = self._request("GET", "/api/stats", token=other_token)
        self.assertEqual(other_stats["total_pets"], 0)
        status, other_meds = self._request("GET", "/api/medications/today", token=other_token)
        self.assertEqual(other_meds, [])

        # Cross-user reads and writes behave as "not found"
        status, _ = self._request("GET", f"/api/pets/{pet_id}", token=other_token)
        self.assertEqual(status, 404)
        status, _ = self._request("PUT", f"/api/pets/{pet_id}", {"name": "Hijacked"}, token=other_token)
        self.assertEqual(status, 404)
        status, _ = self._request("DELETE", f"/api/pets/{pet_id}", token=other_token)
        self.assertEqual(status, 404)
        status, _ = self._request("PUT", f"/api/medications/{med_id}", {"dosage": "99 pills"},
                                   token=other_token)
        self.assertEqual(status, 404)
        status, _ = self._request("POST", f"/api/pets/{pet_id}/weights", {"weight": 1.0},
                                   token=other_token)
        self.assertEqual(status, 404)

        # First user's pet is untouched, then clean up
        status, retrieved = self._request("GET", f"/api/pets/{pet_id}")
        self.assertEqual(status, 200)
        self.assertEqual(retrieved["name"], "Isolation Pup")
        status, _ = self._request("DELETE", f"/api/pets/{pet_id}")
        self.assertEqual(status, 200)

    def test_09_delete_only_from_edit_modal(self):
        """Pet deletion is offered only in the edit-pet modal."""
        status, js = self._request("GET", "/app.js")
        self.assertEqual(status, 200)
        # No delete affordance on the home-page pet cards ...
        self.assertNotIn("delete-pet-card-btn", js)
        # ... nor on the pet detail banner; the edit modal keeps the only one.
        self.assertNotIn("DetailDeletePetBtn", js)
        self.assertIn("petFormDeleteBtn", js)

        status, html = self._request("GET", "/")
        self.assertEqual(status, 200)
        self.assertIn('id="petFormDeleteBtn"', html)
        self.assertIn('id="deleteConfirmModal"', html)

    def test_10_username_uniqueness(self):
        """Usernames cannot be duplicated: exact, padded, or case variants."""
        status, _ = self._request("POST", "/api/auth/signup",
                                  {"username": "UniqueUma", "password": "uniquepass123"},
                                  token=None)
        self.assertEqual(status, 201)

        # Exact duplicate is rejected
        status, _ = self._request("POST", "/api/auth/signup",
                                  {"username": "UniqueUma", "password": "otherpass123"},
                                  token=None)
        self.assertEqual(status, 409)

        # Surrounding whitespace does not create a distinct username
        status, _ = self._request("POST", "/api/auth/signup",
                                  {"username": "  UniqueUma  ", "password": "otherpass123"},
                                  token=None)
        self.assertEqual(status, 409)

        # Case variants are rejected through the API ...
        status, _ = self._request("POST", "/api/auth/signup",
                                  {"username": "uniqueuma", "password": "otherpass123"},
                                  token=None)
        self.assertEqual(status, 409)

        # ... and blocked at the database level even if the app check is bypassed
        conn = database.get_db_connection()
        try:
            with self.assertRaises(sqlite3.IntegrityError):
                conn.execute(
                    "INSERT INTO users (username, password_hash, display_name, created_at) "
                    "VALUES (?, ?, ?, ?)",
                    ("UNIQUEUMA", "x", "x", "2026-01-01"),
                )
        finally:
            conn.close()

    def test_11_pet_photo_upload_and_delete(self):
        """Test uploading, serving, updating, and deleting pet profile pictures."""
        # 1. Create a pet
        status, pet = self._request("POST", "/api/pets", {
            "name": "Photo Pup",
            "species": "Dog",
            "breed": "Beagle",
            "weight": 20.0,
        })
        self.assertEqual(status, 201)
        pet_id = pet["id"]
        self.assertEqual(pet.get("photo_url"), "")

        # 2. Upload photo via multipart
        fake_png = b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15c4\x00\x00\x00\nIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82"
        status, upload_res = self._multipart_upload(
            f"/api/pets/{pet_id}/photo", "beagle.png", fake_png, "image/png", token=self.auth_token
        )
        self.assertEqual(status, 200)
        self.assertIn("photo_url", upload_res)
        photo_url = upload_res["photo_url"]
        self.assertTrue(photo_url.startswith("/uploads/pet_"))
        self.assertTrue(photo_url.endswith(".png"))
        self.assertEqual(upload_res["pet"]["photo_url"], photo_url)

        # 3. Retrieve the photo via GET /uploads/...
        req = urllib.request.Request(f"http://127.0.0.1:{TEST_PORT}{photo_url}")
        with urllib.request.urlopen(req) as resp:
            self.assertEqual(resp.status, 200)
            self.assertIn("image/png", resp.headers.get("Content-Type", ""))
            fetched_bytes = resp.read()
            self.assertEqual(fetched_bytes, fake_png)

        # 4. Check pet via GET /api/pets/<id>
        status, pet_fetched = self._request("GET", f"/api/pets/{pet_id}")
        self.assertEqual(status, 200)
        self.assertEqual(pet_fetched["photo_url"], photo_url)

        # 5. Upload second photo via base64 JSON payload
        fake_jpg_b64 = "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA="
        status, json_upload = self._request("POST", f"/api/pets/{pet_id}/photo", {
            "image": fake_jpg_b64,
            "filename": "cute_beagle.jpg"
        })
        self.assertEqual(status, 200)
        second_photo_url = json_upload["photo_url"]
        self.assertTrue(second_photo_url.endswith(".jpg") or second_photo_url.endswith(".jpeg"))
        self.assertNotEqual(photo_url, second_photo_url)

        # Old file should have been cleaned up
        old_file_path = os.path.join("uploads", os.path.basename(photo_url))
        self.assertFalse(os.path.exists(old_file_path))

        # 6. Test general upload endpoint POST /api/upload
        status, gen_upload = self._request("POST", "/api/upload", {
            "image": fake_jpg_b64,
            "filename": "new_pet.jpg"
        })
        self.assertEqual(status, 201)
        self.assertIn("photo_url", gen_upload)
        new_pet_photo = gen_upload["photo_url"]

        # Create pet with photo_url
        status, pet_with_photo = self._request("POST", "/api/pets", {
            "name": "Pre-photo Cat",
            "species": "Cat",
            "photo_url": new_pet_photo
        })
        self.assertEqual(status, 201)
        self.assertEqual(pet_with_photo["photo_url"], new_pet_photo)

        # 7. Test user isolation
        status, other_user = self._request("POST", "/api/auth/signup",
                                          {"username": "otherphoto", "password": "otherpass123"},
                                          token=None)
        other_token = other_user["token"]
        status, _ = self._request("POST", f"/api/pets/{pet_id}/photo",
                                  {"image": fake_jpg_b64}, token=other_token)
        self.assertEqual(status, 404)
        status, _ = self._request("DELETE", f"/api/pets/{pet_id}/photo", token=other_token)
        self.assertEqual(status, 404)

        # 8. Delete pet photo via DELETE /api/pets/<id>/photo
        status, del_res = self._request("DELETE", f"/api/pets/{pet_id}/photo")
        self.assertEqual(status, 200)
        self.assertEqual(del_res["pet"]["photo_url"], "")

        # Verify database record
        status, pet_cleared = self._request("GET", f"/api/pets/{pet_id}")
        self.assertEqual(pet_cleared["photo_url"], "")

        # Cleanup pets
        self._request("DELETE", f"/api/pets/{pet_id}")
        self._request("DELETE", f"/api/pets/{pet_with_photo['id']}")

    def test_12_heif_photo_upload_and_serve(self):
        """HEIF photos upload, keep their extension, and serve as images."""
        # Minimal ISO-BMFF ftyp box branded as HEIF.
        fake_heif = (
            b"\x00\x00\x00\x20"  # box size
            b"ftyp"              # box type
            b"heic"              # major brand
            b"\x00\x00\x00\x00"  # minor version
            b"heic" b"mif1"      # compatible brands
            b"\x00\x00\x00\x08mdat"
        )
        status, pet = self._request("POST", "/api/pets", {
            "name": "HEIF Pup",
            "species": "Dog",
            "breed": "Beagle",
            "weight": 20.0,
        })
        self.assertEqual(status, 201)
        pet_id = pet["id"]

        try:
            # 1. Multipart upload with a .heif filename is accepted as-is.
            status, upload_res = self._multipart_upload(
                f"/api/pets/{pet_id}/photo", "puppy.heif", fake_heif,
                "image/heif", token=self.auth_token
            )
            self.assertEqual(status, 200)
            photo_url = upload_res["photo_url"]
            self.assertTrue(photo_url.endswith(".heif"))
            self.assertEqual(upload_res["pet"]["photo_url"], photo_url)

            # 2. Served back with an HEIF image content type.
            req = urllib.request.Request(f"http://127.0.0.1:{TEST_PORT}{photo_url}")
            with urllib.request.urlopen(req) as resp:
                self.assertEqual(resp.status, 200)
                self.assertIn("image/heif", resp.headers.get("Content-Type", ""))
                self.assertEqual(resp.read(), fake_heif)

            # 3. HEIF bytes with an unusable filename are detected, not rejected.
            status, sniffed = self._multipart_upload(
                f"/api/pets/{pet_id}/photo", "puppy.bin", fake_heif,
                "application/octet-stream", token=self.auth_token
            )
            self.assertEqual(status, 200)
            self.assertTrue(sniffed["photo_url"].endswith(".heif"))

            # 4. The .heic spelling of the same format works too.
            status, heic_res = self._multipart_upload(
                f"/api/pets/{pet_id}/photo", "puppy.heic", fake_heif,
                "image/heic", token=self.auth_token
            )
            self.assertEqual(status, 200)
            self.assertTrue(heic_res["photo_url"].endswith(".heic"))
            req = urllib.request.Request(
                f"http://127.0.0.1:{TEST_PORT}{heic_res['photo_url']}"
            )
            with urllib.request.urlopen(req) as resp:
                self.assertEqual(resp.status, 200)
                self.assertIn("image/heic", resp.headers.get("Content-Type", ""))
        finally:
            self._request("DELETE", f"/api/pets/{pet_id}")

if __name__ == "__main__":
    unittest.main()
