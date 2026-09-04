#!/usr/bin/env python3
import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer

HOST = "0.0.0.0"
PORT = 2786
API_KEY = os.environ.get("API_MASTER_KEY", "")

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"status":"ok"}')
            return
        self.send_response(404)
        self.end_headers()

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length) if length else b""
        key = self.headers.get("X-API-Key", "")
        if key != API_KEY:
            self.send_response(401)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"error":"invalid_api_key"}')
            return

        try:
            payload = json.loads(body.decode("utf-8")) if body else {}
        except Exception:
            payload = {}

        chat_id = payload.get("chat_id") or payload.get("chatId")
        message = payload.get("message") or ""

        if not chat_id or not message:
            self.send_response(400)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"error":"missing_chat_id_or_message"}')
            return

        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps({"status":"ok","chat_id": chat_id, "message": message}).encode())

    def log_message(self, format, *args):
        return

server = HTTPServer((HOST, PORT), Handler)
print(f"[OpenWA helper] running on http://{HOST}:{PORT}")
server.serve_forever()
