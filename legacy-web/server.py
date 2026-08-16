#!/usr/bin/env python3
import base64
import json
import os
import re
import subprocess
import uuid
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

ROOT = os.path.dirname(os.path.abspath(__file__))
os.chdir(ROOT)
PORT = int(os.environ.get("PORT", "5173"))
LIBRARY = os.path.join(ROOT, "data", "library.json")
SHARED = os.path.join(ROOT, "assets", "shared")


def load_library():
    if not os.path.isfile(LIBRARY):
        return {"photos": []}
    with open(LIBRARY, "r", encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data.get("photos"), list):
        data["photos"] = []
    return data


def save_library(data):
    os.makedirs(os.path.dirname(LIBRARY), exist_ok=True)
    with open(LIBRARY, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")


def decode_jpeg(data_url):
    match = re.match(r"^data:image/jpeg;base64,(.+)$", data_url or "", re.I | re.S)
    if not match:
        raise ValueError("jpeg data URL only")
    raw = base64.b64decode(match.group(1))
    if len(raw) > 900_000:
        raise ValueError("image too large")
    return raw


def git_publish(paths, message):
    env = os.environ.copy()
    git = os.path.join(os.environ.get("ProgramFiles", r"C:\Program Files"), "Git", "cmd", "git.exe")
    exe = git if os.path.isfile(git) else "git"
    subprocess.run([exe, "add", *paths], cwd=ROOT, check=False)
    subprocess.run(
        [
            exe,
            "-c",
            "user.name=youngbokkim",
            "-c",
            "user.email=34362255+youngbokkim@users.noreply.github.com",
            "commit",
            "-m",
            message,
        ],
        cwd=ROOT,
        check=False,
    )
    subprocess.run([exe, "push", "origin", "main"], cwd=ROOT, check=False)


class Handler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()

    def _json(self, code, payload):
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _read_json(self):
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length) if length else b"{}"
        return json.loads(raw.decode("utf-8"))

    def do_GET(self):
        path = self.path.split("?", 1)[0]
        if path == "/api/status":
            return self._json(200, {"ok": True, "mode": "local-api"})
        if path == "/api/photos":
            return self._json(200, load_library())
        return super().do_GET()

    def do_POST(self):
        path = self.path.split("?", 1)[0]
        if path != "/api/photos":
            self.send_error(404)
            return
        try:
            payload = self._read_json()
            name = str(payload.get("name") or "").strip()
            image = payload.get("image") or ""
            if not name or not image:
                raise ValueError("name and image required")
            photo_id = str(payload.get("id") or uuid.uuid4())
            jpeg = decode_jpeg(image)
            os.makedirs(SHARED, exist_ok=True)
            rel = f"assets/shared/{photo_id}.jpg"
            with open(os.path.join(ROOT, *rel.split("/")), "wb") as f:
                f.write(jpeg)
            library = load_library()
            library["photos"] = [p for p in library["photos"] if p.get("id") != photo_id]
            photo = {
                "id": photo_id,
                "name": name,
                "morphId": payload.get("morphId"),
                "file": rel,
                "signature": payload.get("signature"),
                "addedAt": payload.get("addedAt") or 0,
            }
            library["photos"].append(photo)
            save_library(library)
            git_publish([rel, "data/library.json"], f"Add shared morph photo: {name}")
            photo = {**photo, "image": rel, "shared": True}
            self._json(200, photo)
        except Exception as exc:
            self._json(400, {"error": str(exc)})

    def do_DELETE(self):
        path = self.path.split("?", 1)[0]
        match = re.match(r"^/api/photos/([^/]+)$", path)
        if not match:
            self.send_error(404)
            return
        photo_id = match.group(1)
        library = load_library()
        photo = next((p for p in library["photos"] if p.get("id") == photo_id), None)
        library["photos"] = [p for p in library["photos"] if p.get("id") != photo_id]
        save_library(library)
        removed = []
        if photo and photo.get("file"):
            abs_path = os.path.join(ROOT, *str(photo["file"]).split("/"))
            if os.path.isfile(abs_path):
                os.remove(abs_path)
                removed.append(photo["file"])
        git_publish(["data/library.json", *removed], f"Remove shared morph photo: {photo_id}")
        self._json(200, {"ok": True})

    def log_message(self, fmt, *args):
        print("[%s] %s" % (self.log_date_time_string(), fmt % args))


if __name__ == "__main__":
    os.makedirs(SHARED, exist_ok=True)
    os.makedirs(os.path.dirname(LIBRARY), exist_ok=True)
    if not os.path.isfile(LIBRARY):
        save_library({"photos": []})
    server = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    print(f"CREHOONI server http://127.0.0.1:{PORT}")
    server.serve_forever()
