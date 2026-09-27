#!/usr/bin/env python3
"""
SimplyPets Web Application Server
A modern pet tracking web server powered by Python 3 standard library and SQLite.
"""

import sys
import os
import json
import mimetypes
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import database

STATIC_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "static")

class PetsRequestHandler(BaseHTTPRequestHandler):
    server_version = "SimplyPets/1.0"

    def _send_json(self, data, status=200):
        body = json.dumps(data, indent=2).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()
        self.wfile.write(body)

    def _send_error(self, message, status=400):
        self._send_json({"error": message}, status=status)

    def _read_json(self):
        try:
            content_length = int(self.headers.get("Content-Length", 0))
            if content_length <= 0:
                return {}
            raw_body = self.rfile.read(content_length).decode("utf-8")
            return json.loads(raw_body)
        except Exception as e:
            raise ValueError(f"Invalid JSON payload: {e}")

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path
        parts = [p for p in path.split("/") if p]

        # API routing
        if path.startswith("/api/"):
            try:
                # GET /api/stats
                if path == "/api/stats":
                    return self._send_json(database.get_stats())

                # GET /api/medications/today
                if path == "/api/medications/today":
                    return self._send_json(database.get_today_medications())

                # GET /api/export
                if path == "/api/export":
                    return self._send_json(database.export_all_data())

                # GET /api/pets
                if path == "/api/pets":
                    return self._send_json(database.get_all_pets())

                # GET /api/pets/<id>
                if len(parts) == 2 and parts[0] == "api" and parts[1].isdigit():
                    pet = database.get_pet_by_id(int(parts[1]))
                    if not pet:
                        return self._send_error("Pet not found", 404)
                    return self._send_json(pet)

                if len(parts) == 3 and parts[0] == "api" and parts[1] == "pets" and parts[2].isdigit():
                    pet = database.get_pet_by_id(int(parts[2]))
                    if not pet:
                        return self._send_error("Pet not found", 404)
                    return self._send_json(pet)

                return self._send_error("API endpoint not found", 404)
            except Exception as e:
                return self._send_error(str(e), 500)

        # Serve static assets
        self._serve_static(path)

    def do_POST(self):
        parsed = urlparse(self.path)
        path = parsed.path
        parts = [p for p in path.split("/") if p]

        if not path.startswith("/api/"):
            return self._send_error("Method Not Allowed", 405)

        try:
            payload = self._read_json()

            # POST /api/demo
            if path == "/api/demo":
                pets = database.seed_demo_data()
                return self._send_json({"message": "Demo data loaded", "pets": pets})

            # POST /api/reset
            if path == "/api/reset":
                database.reset_all_data()
                return self._send_json({"message": "All data cleared"})

            # POST /api/import
            if path == "/api/import":
                count = database.import_all_data(payload)
                return self._send_json({"message": f"Successfully imported {count} pets"})

            # POST /api/pets
            if path == "/api/pets":
                new_pet = database.create_pet(payload)
                return self._send_json(new_pet, 201)

            # POST /api/pets/<id>/medications
            if len(parts) == 4 and parts[0] == "api" and parts[1] == "pets" and parts[2].isdigit() and parts[3] == "medications":
                pet_id = int(parts[2])
                med = database.add_medication(pet_id, payload)
                return self._send_json(med, 201)

            # POST /api/pets/<id>/weights
            if len(parts) == 4 and parts[0] == "api" and parts[1] == "pets" and parts[2].isdigit() and parts[3] == "weights":
                pet_id = int(parts[2])
                weight = payload.get("weight")
                unit = payload.get("weight_unit", "lbs")
                logged_date = payload.get("logged_date")
                notes = payload.get("notes", "")
                entry = database.add_weight_log(pet_id, weight, unit, logged_date, notes)
                return self._send_json(entry, 201)

            # POST /api/medications/<id>/dose
            if len(parts) == 4 and parts[0] == "api" and parts[1] == "medications" and parts[2].isdigit() and parts[3] == "dose":
                med_id = int(parts[2])
                notes = payload.get("notes", "")
                dose = database.log_dose(med_id, notes)
                if not dose:
                    return self._send_error("Medication not found", 404)
                return self._send_json(dose, 201)

            return self._send_error("API endpoint not found", 404)
        except ValueError as ve:
            return self._send_error(str(ve), 400)
        except Exception as e:
            return self._send_error(str(e), 500)

    def do_PUT(self):
        parsed = urlparse(self.path)
        path = parsed.path
        parts = [p for p in path.split("/") if p]

        if not path.startswith("/api/"):
            return self._send_error("Method Not Allowed", 405)

        try:
            payload = self._read_json()

            # PUT /api/pets/<id>
            if len(parts) == 3 and parts[0] == "api" and parts[1] == "pets" and parts[2].isdigit():
                pet_id = int(parts[2])
                updated = database.update_pet(pet_id, payload)
                if not updated:
                    return self._send_error("Pet not found", 404)
                return self._send_json(updated)

            # PUT /api/medications/<id>
            if len(parts) == 3 and parts[0] == "api" and parts[1] == "medications" and parts[2].isdigit():
                med_id = int(parts[2])
                updated = database.update_medication(med_id, payload)
                if not updated:
                    return self._send_error("Medication not found", 404)
                return self._send_json(updated)

            return self._send_error("API endpoint not found", 404)
        except ValueError as ve:
            return self._send_error(str(ve), 400)
        except Exception as e:
            return self._send_error(str(e), 500)

    def do_DELETE(self):
        parsed = urlparse(self.path)
        path = parsed.path
        parts = [p for p in path.split("/") if p]

        if not path.startswith("/api/"):
            return self._send_error("Method Not Allowed", 405)

        try:
            # DELETE /api/pets/<id>
            if len(parts) == 3 and parts[0] == "api" and parts[1] == "pets" and parts[2].isdigit():
                pet_id = int(parts[2])
                if database.delete_pet(pet_id):
                    return self._send_json({"message": "Pet deleted successfully"})
                return self._send_error("Pet not found", 404)

            # DELETE /api/medications/<id>
            if len(parts) == 3 and parts[0] == "api" and parts[1] == "medications" and parts[2].isdigit():
                med_id = int(parts[2])
                if database.delete_medication(med_id):
                    return self._send_json({"message": "Medication deleted successfully"})
                return self._send_error("Medication not found", 404)

            # DELETE /api/weights/<id>
            if len(parts) == 3 and parts[0] == "api" and parts[1] == "weights" and parts[2].isdigit():
                weight_id = int(parts[2])
                if database.delete_weight_log(weight_id):
                    return self._send_json({"message": "Weight log deleted successfully"})
                return self._send_error("Weight entry not found", 404)

            return self._send_error("API endpoint not found", 404)
        except Exception as e:
            return self._send_error(str(e), 500)

    def _serve_static(self, path):
        # Default to index.html
        if path in ("", "/"):
            file_path = os.path.join(STATIC_DIR, "index.html")
        else:
            rel_path = path.lstrip("/")
            file_path = os.path.join(STATIC_DIR, rel_path)

        # Normalize and ensure security (prevent directory traversal)
        norm_file = os.path.abspath(file_path)
        if not norm_file.startswith(os.path.abspath(STATIC_DIR)):
            self.send_error(403, "Forbidden")
            return

        if not os.path.exists(norm_file) or os.path.isdir(norm_file):
            # SPA fallback: if not an api or asset request, serve index.html
            fallback = os.path.join(STATIC_DIR, "index.html")
            if os.path.exists(fallback):
                norm_file = fallback
            else:
                self.send_error(404, "File Not Found")
                return

        ctype, _ = mimetypes.guess_type(norm_file)
        if not ctype:
            ctype = "application/octet-stream"
        if norm_file.endswith(".js"):
            ctype = "application/javascript; charset=utf-8"
        elif norm_file.endswith(".css"):
            ctype = "text/css; charset=utf-8"
        elif norm_file.endswith(".html"):
            ctype = "text/html; charset=utf-8"
        elif norm_file.endswith(".svg"):
            ctype = "image/svg+xml"

        try:
            with open(norm_file, "rb") as f:
                content = f.read()
            self.send_response(200)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(content)))
            self.send_header("Cache-Control", "no-cache")
            self.end_headers()
            self.wfile.write(content)
        except Exception as e:
            self.send_error(500, f"Error reading file: {e}")

    def log_message(self, format, *args):
        # Concise server logging
        sys.stderr.write(f"[{self.log_date_time_string()}] {args[0]} - {args[1]} {args[2]}\n")

def run(host="127.0.0.1", port=8080):
    database.init_db()

    # If first time running and no pets exist, automatically seed demo pets
    existing_pets = database.get_all_pets()
    if not existing_pets:
        print("🌱 First run detected: Seeding initial demo pet data...")
        database.seed_demo_data()

    # Find open port if 8080 is busy
    attempts = 0
    server = None
    while attempts < 20:
        target_port = port + attempts
        try:
            server = HTTPServer((host, target_port), PetsRequestHandler)
            port = target_port
            break
        except OSError:
            attempts += 1

    if not server:
        print(f"❌ Error: Could not bind server to ports {port}-{port+20}")
        sys.exit(1)

    url = f"http://{host}:{port}"
    print("=" * 60)
    print(f"🐾 SimplyPets Web Application is running!")
    print(f"🌐 Access the app at: {url}")
    print(f"📁 Static assets: {STATIC_DIR}")
    print(f"💾 SQLite Database: {database.DB_PATH}")
    print("=" * 60)
    print("Press Ctrl+C to stop the server.\n")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n🛑 Shutting down SimplyPets server...")
        server.server_close()

if __name__ == "__main__":
    p = 8080
    if len(sys.argv) > 1 and sys.argv[1].isdigit():
        p = int(sys.argv[1])
    run(port=p)
