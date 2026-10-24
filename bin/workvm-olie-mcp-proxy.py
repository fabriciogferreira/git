#!/usr/bin/env python3
# O Cursor vê o OAuth em api.olie.ai e ignora o Bearer do mcp.json.
# O desktop fica "autenticado" e o agente do prompt recebe needsAuth.
# Este processo responde 404 na descoberta OAuth e encaminha
# /mcp/management com OLIE_FLOW_AI_MCP_TOKEN. Não grava o token.
# Porta fixa 127.0.0.1:47331 — a mesma que workvm_apply_mcp escreve.

from __future__ import annotations

import http.client
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

HOST = "127.0.0.1"
PORT = 47331
UPSTREAM = "api.olie.ai"
FORWARD = {
    "accept",
    "content-type",
    "mcp-session-id",
    "mcp-protocol-version",
    "last-event-id",
}


def load_token() -> str:
    value = ""
    directory = Path.home() / ".config" / "environment.d"
    if directory.is_dir():
        for path in sorted(directory.glob("*.conf")):
            try:
                lines = path.read_text(encoding="utf-8").splitlines()
            except OSError:
                continue
            for line in lines:
                if line.startswith("OLIE_FLOW_AI_MCP_TOKEN="):
                    value = line.split("=", 1)[1].strip().strip('"').strip("'")
    import os
    return os.environ.get("OLIE_FLOW_AI_MCP_TOKEN") or value


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_GET(self) -> None:
        self._handle()

    def do_POST(self) -> None:
        self._handle()

    def do_DELETE(self) -> None:
        self._handle()

    def do_OPTIONS(self) -> None:
        if self._discovery():
            self._empty(404)
            return
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS")
        self.send_header(
            "Access-Control-Allow-Headers",
            "Authorization, Content-Type, Accept, Mcp-Session-Id, Mcp-Protocol-Version",
        )
        self.send_header("Content-Length", "0")
        self.end_headers()

    def _discovery(self) -> bool:
        path = self.path.split("?", 1)[0]
        return ".well-known/" in path

    def _empty(self, status: int) -> None:
        self.send_response(status)
        self.send_header("Content-Length", "0")
        self.end_headers()

    def _handle(self) -> None:
        if self._discovery():
            self._empty(404)
            return

        token = load_token()
        if not token:
            self._empty(503)
            return

        length = int(self.headers.get("Content-Length", "0") or "0")
        body = self.rfile.read(length) if length else None
        headers = {"Host": UPSTREAM, "Authorization": f"Bearer {token}"}
        for key, value in self.headers.items():
            if key.lower() in FORWARD and value:
                headers[key] = value

        connection = http.client.HTTPSConnection(UPSTREAM, timeout=None)
        try:
            connection.request(self.command, self.path, body=body, headers=headers)
            upstream = connection.getresponse()
            self.send_response(upstream.status)
            for key, value in upstream.getheaders():
                lowered = key.lower()
                if lowered in {"transfer-encoding", "connection", "content-length", "authorization"}:
                    continue
                self.send_header(key, value)
            content_type = upstream.getheader("Content-Type") or ""
            if "text/event-stream" in content_type:
                self.end_headers()
                while True:
                    chunk = upstream.read(4096)
                    if not chunk:
                        break
                    self.wfile.write(chunk)
                    self.wfile.flush()
                return
            payload = upstream.read()
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
        except (http.client.HTTPException, OSError):
            self._empty(502)
        finally:
            connection.close()

    def log_message(self, fmt: str, *args: object) -> None:
        print(f"olie-mcp-proxy {self.command} {self.path.split('?', 1)[0]}", flush=True)


def main() -> None:
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"olie-mcp-proxy http://{HOST}:{PORT}/mcp/management", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
