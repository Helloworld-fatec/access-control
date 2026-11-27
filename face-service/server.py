"""
Servidor HTTP (apenas biblioteca padrão + numpy/opencv).

Rotas:
  GET  /                    -> interface (index.html)
  POST /api/enroll          -> corpo = bytes da imagem; cadastra o rosto
  POST /api/match?threshold -> corpo = frame JPEG; devolve rostos + score + match
  POST /api/reset           -> limpa o rosto cadastrado

Uso:  python server.py [porta]
"""
import base64
import json
import mimetypes
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

import cv2
import numpy as np

import hog_face

# Os arquivos da interface ficam ao lado deste script.
STATIC = Path(__file__).parent.resolve()
MAX_BODY = 20 * 1024 * 1024  # 20 MB

state = {"bank": None, "users": {}}
state_lock = threading.Lock()


def decode_gray(data, max_side=1280):
    img = cv2.imdecode(np.frombuffer(data, np.uint8), cv2.IMREAD_COLOR)
    if img is None:
        return None
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    h, w = gray.shape
    if max(h, w) > max_side:
        s = max_side / max(h, w)
        gray = cv2.resize(gray, (int(w * s), int(h * s)), interpolation=cv2.INTER_AREA)
    return gray


class Handler(BaseHTTPRequestHandler):
    # ---------- helpers ----------
    def send_json(self, obj, status=200):
        body = json.dumps(obj).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def read_body(self):
        n = int(self.headers.get("Content-Length", 0))
        if n <= 0 or n > MAX_BODY:
            return None
        return self.rfile.read(n)

    # ---------- GET (arquivos estáticos e status) ----------
    def do_GET(self):
        url = urlparse(self.path)
        path = url.path
        if path == "/api/status" or path == "/api/users":
            with state_lock:
                users_list = [
                    {"userId": uid, "name": udata.get("name"), "variants": int(udata["bank"].shape[0])}
                    for uid, udata in state["users"].items()
                ]
                has_default_bank = state["bank"] is not None
            self.send_json({
                "ok": True,
                "users_count": len(users_list),
                "has_default_bank": has_default_bank,
                "users": users_list,
            })
            return

        if path == "/":
            path = "/index.html"
        file = (STATIC / path.lstrip("/")).resolve()
        if STATIC not in file.parents or not file.is_file():
            self.send_json({"error": "não encontrado"}, 404)
            return
        data = file.read_bytes()
        ctype = mimetypes.guess_type(file.name)[0] or "application/octet-stream"
        self.send_response(200)
        self.send_header("Content-Type", f"{ctype}; charset=utf-8" if ctype.startswith("text") or ctype.endswith("javascript") else ctype)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    # ---------- POST (API) ----------
    def do_POST(self):
        url = urlparse(self.path)
        query = parse_qs(url.query)
        if url.path == "/api/enroll":
            self.enroll(query)
        elif url.path == "/api/match":
            self.match(query)
        elif url.path == "/api/reset":
            with state_lock:
                state["bank"] = None
                state["users"] = {}
            self.send_json({"ok": True})
        else:
            self.send_json({"error": "rota inexistente"}, 404)

    def enroll(self, query):
        data = self.read_body()
        gray = decode_gray(data) if data else None
        if gray is None:
            return self.send_json({"error": "Imagem inválida."}, 400)

        faces = hog_face.detect_faces(gray, min_size=60)
        if not faces:
            return self.send_json({"error": "Nenhum rosto detectado. Use uma foto frontal e bem iluminada."}, 422)
        box = max(faces, key=lambda b: b[2] * b[3])  # maior rosto

        bank = hog_face.enroll_embeddings(gray, box)
        user_id = query.get("userId", [None])[0]
        user_name = query.get("name", [None])[0]

        with state_lock:
            state["bank"] = bank
            if user_id:
                state["users"][user_id] = {"name": user_name, "bank": bank}

        vis = hog_face.hog_visual(gray, box)
        ok, png = cv2.imencode(".png", vis)
        h, w = gray.shape
        self.send_json({
            "ok": True,
            "userId": user_id,
            "userName": user_name,
            "faces_found": len(faces),
            "box": box,
            "image_w": w,
            "image_h": h,
            "dims": int(bank.shape[1]),
            "variants": int(bank.shape[0]),
            "hog_png": "data:image/png;base64," + base64.b64encode(png.tobytes()).decode(),
        })

    def match(self, query):
        with state_lock:
            bank = state["bank"]
            users = dict(state["users"])

        if bank is None and not users:
            return self.send_json({"enrolled": False, "faces": []})

        data = self.read_body()
        gray = decode_gray(data, max_side=640) if data else None
        if gray is None:
            return self.send_json({"error": "Frame inválido."}, 400)

        try:
            threshold = float(query.get("threshold", ["0.55"])[0])
        except ValueError:
            threshold = 0.55

        target_user_id = query.get("userId", [None])[0]

        out = []
        for box in hog_face.detect_faces(gray, min_size=50):
            emb = hog_face.embedding(gray, box)
            if target_user_id and target_user_id in users:
                # Verificação 1-para-1 específica
                udata = users[target_user_id]
                score = hog_face.similarity(udata["bank"], emb)
                out.append({
                    "box": box,
                    "score": round(score, 4),
                    "match": score >= threshold,
                    "userId": target_user_id,
                    "userName": udata.get("name"),
                })
            elif users:
                # Identificação 1-para-N entre todos os usuários cadastrados
                best_score = -1.0
                best_uid = None
                best_name = None
                for uid, udata in users.items():
                    s = hog_face.similarity(udata["bank"], emb)
                    if s > best_score:
                        best_score = s
                        best_uid = uid
                        best_name = udata.get("name")
                out.append({
                    "box": box,
                    "score": round(best_score, 4),
                    "match": best_score >= threshold,
                    "userId": best_uid if best_score >= threshold else None,
                    "userName": best_name if best_score >= threshold else None,
                })
            else:
                # Modo original com banco único
                score = hog_face.similarity(bank, emb)
                out.append({"box": box, "score": round(score, 4), "match": score >= threshold})

        h, w = gray.shape
        self.send_json({
            "enrolled": True,
            "frame_w": w,
            "frame_h": h,
            "faces": out,
            "users_count": len(users),
        })

    def log_message(self, fmt, *args):
        if "/api/match" not in (args[0] if args else ""):  # evita spam de log
            super().log_message(fmt, *args)


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
    srv = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    print(f"Abra http://localhost:{port}  (Ctrl+C para sair)")
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass
