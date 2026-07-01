#!/usr/bin/env python3
import http.server
import hmac
import logging
import os
import socketserver
import subprocess
import urllib.parse


LISTEN_IP = os.environ.get("ROUTER_TAILSCALE_IP", "127.0.0.1")
LISTEN_PORT = int(os.environ.get("ROUTER_API_PORT", "8080"))
TOKEN_FILE = os.environ.get("AUTH_TOKEN_FILE", "/opt/share/pc-control/.token")
WOL_INTERFACE = os.environ.get("WOL_LAN_INTERFACE", "br0")
WOL_TARGET_MAC = os.environ["WOL_TARGET_MAC"]
ETHER_WAKE = os.environ.get("ETHER_WAKE", "/usr/sbin/ether-wake")

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

        if path == "/wake":
            logging.info("wake authorized")
            try:
                subprocess.run(
                    [ETHER_WAKE, "-i", WOL_INTERFACE, "-b", WOL_TARGET_MAC],
                    check=True,
                )
            except subprocess.CalledProcessError:
                logging.exception("wake command failed")
                self._respond(500, "Wake command failed")
            else:
                self._respond(200, "Wake packet sent")
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
        logging.info("Router wake API listening on %s:%s", LISTEN_IP, LISTEN_PORT)
        httpd.serve_forever()
