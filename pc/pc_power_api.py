#!/usr/bin/env python3
import http.server
import hmac
import logging
import os
import socketserver
import subprocess
import urllib.parse


LISTEN_IP = os.environ.get("PC_TAILSCALE_IP", "127.0.0.1")
LISTEN_PORT = int(os.environ.get("PC_API_PORT", "8081"))
TOKEN_FILE = os.environ.get("AUTH_TOKEN_FILE", "/etc/phone-wol-power/token")
SHUTDOWN_CMD = os.environ.get(
    "SHUTDOWN_CMD", "sudo -n /usr/local/sbin/pc_poweroff_with_wol"
).split()
SUSPEND_CMD = os.environ.get(
    "SUSPEND_CMD", "sudo -n /usr/local/sbin/pc_suspend_with_wol"
).split()


with open(TOKEN_FILE, encoding="utf-8") as f:
    TOKEN = f.read().strip()

if len(TOKEN) < 20:
    raise SystemExit("Refusing to start with a short bearer token")


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        path = urllib.parse.urlparse(self.path).path
        auth = self.headers.get("Authorization", "")
        if not hmac.compare_digest(auth, f"Bearer {TOKEN}"):
            self._respond(403, "Forbidden")
            return

        if path == "/shutdown":
            logging.info("shutdown authorized")
            self._respond(200, "Shutting down...")
            subprocess.Popen(SHUTDOWN_CMD)
        elif path == "/suspend":
            logging.info("suspend authorized")
            self._respond(200, "Suspending...")
            subprocess.Popen(SUSPEND_CMD)
        elif path == "/status":
            self._respond(200, "ON")
        else:
            self._respond(404, "Not Found")

    def _respond(self, code, msg):
        body = msg.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_args):
        return


class ThreadedServer(socketserver.ThreadingMixIn, socketserver.TCPServer):
    allow_reuse_address = True
    daemon_threads = True


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    with ThreadedServer((LISTEN_IP, LISTEN_PORT), Handler) as httpd:
        logging.info("PC power API listening on %s:%s", LISTEN_IP, LISTEN_PORT)
        httpd.serve_forever()
