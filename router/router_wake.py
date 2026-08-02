#!/usr/bin/env python3
import http.server
import hmac
import ipaddress
import logging
import os
import socket
import socketserver
import subprocess
import urllib.error
import urllib.parse
import urllib.request


LISTEN_IP = os.environ.get(
    "ROUTER_LISTEN_IP", os.environ.get("ROUTER_TAILSCALE_IP", "127.0.0.1")
)
LISTEN_PORT = int(os.environ.get("ROUTER_API_PORT", "8080"))
TOKEN_FILE = os.environ.get("AUTH_TOKEN_FILE", "/opt/share/pc-control/.token")
WOL_INTERFACE = os.environ.get("WOL_LAN_INTERFACE", "br0")
WOL_TARGET_MAC = os.environ["WOL_TARGET_MAC"]
ETHER_WAKE = os.environ.get("ETHER_WAKE", "/usr/sbin/ether-wake")
ALLOWED_CLIENT_NETS = os.environ.get("ROUTER_ALLOWED_CLIENT_NETS", "")
PC_API_TARGETS_VALUE = os.environ.get("PC_API_TARGETS", "")
PC_AUTH_TOKEN_FILE = os.environ.get("PC_AUTH_TOKEN_FILE", "")
PC_API_TIMEOUT_SECONDS = float(os.environ.get("PC_API_TIMEOUT_SECONDS", "2"))


def _read_token(path, label):
    with open(path, encoding="utf-8") as token_file:
        token = token_file.read().strip()
    if len(token) < 20:
        raise SystemExit("Refusing to start with a short {} bearer token".format(label))
    return token


def _parse_pc_api_targets(value):
    targets = []
    for item in value.split(","):
        target = item.strip().rstrip("/")
        if not target:
            continue
        parsed = urllib.parse.urlsplit(target)
        try:
            port = parsed.port
        except ValueError:
            port = None
        if (
            parsed.scheme != "http"
            or not parsed.hostname
            or port is None
            or parsed.username
            or parsed.password
            or parsed.path not in ("", "/")
            or parsed.query
            or parsed.fragment
        ):
            raise SystemExit(
                "Invalid PC_API_TARGETS entry (expected http://host:port): {}".format(
                    item.strip()
                )
            )
        if target not in targets:
            targets.append(target)
    return targets


TOKEN = _read_token(TOKEN_FILE, "router")
PC_API_TARGETS = _parse_pc_api_targets(PC_API_TARGETS_VALUE)

if not 0.2 <= PC_API_TIMEOUT_SECONDS <= 10:
    raise SystemExit("PC_API_TIMEOUT_SECONDS must be between 0.2 and 10")

if PC_API_TARGETS:
    if not PC_AUTH_TOKEN_FILE:
        raise SystemExit("Set PC_AUTH_TOKEN_FILE when PC_API_TARGETS is configured")
    PC_TOKEN = _read_token(PC_AUTH_TOKEN_FILE, "PC")
else:
    PC_TOKEN = None


def _parse_allowed_networks(value):
    networks = []
    for item in value.split(","):
        item = item.strip()
        if not item:
            continue
        networks.append(ipaddress.ip_network(item, strict=False))
    return networks


ALLOWED_NETWORKS = _parse_allowed_networks(ALLOWED_CLIENT_NETS)


def _proxy_to_active_pc(path):
    for target in PC_API_TARGETS:
        url = target + path
        request = urllib.request.Request(
            url,
            headers={"Authorization": "Bearer {}".format(PC_TOKEN)},
            method="GET",
        )
        try:
            with urllib.request.urlopen(
                request, timeout=PC_API_TIMEOUT_SECONDS
            ) as response:
                body = response.read(4096).decode("utf-8", errors="replace")
                if response.status == 200:
                    logging.info("%s handled by %s", path, target)
                    return 200, body
                logging.warning(
                    "PC API %s returned HTTP %s for %s",
                    target,
                    response.status,
                    path,
                )
        except urllib.error.HTTPError as exc:
            logging.warning("PC API %s returned HTTP %s for %s", target, exc.code, path)
            if exc.code == 403:
                return 502, "Active PC API rejected the configured token"
        except (urllib.error.URLError, TimeoutError, socket.timeout, OSError) as exc:
            logging.info("PC API %s unavailable for %s: %s", target, path, exc)

    return 503, "No active PC OS API found"


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        path = urllib.parse.urlparse(self.path).path
        if ALLOWED_NETWORKS and not self._client_allowed():
            logging.warning("client denied by allowlist: %s", self.client_address[0])
            self._respond(403, "Forbidden")
            return

        if path == "/wake":
            auth = self.headers.get("Authorization", "")
            if not hmac.compare_digest(auth, f"Bearer {TOKEN}"):
                self._respond(403, "Forbidden")
                return
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
        elif path in ("/status", "/suspend", "/shutdown") and PC_API_TARGETS:
            auth = self.headers.get("Authorization", "")
            if not hmac.compare_digest(auth, f"Bearer {PC_TOKEN}"):
                self._respond(403, "Forbidden")
                return
            logging.info("%s authorized for OS auto-detection", path)
            code, message = _proxy_to_active_pc(path)
            self._respond(code, message)
        else:
            self._respond(404, "Not Found")

    def _client_allowed(self):
        try:
            client_ip = ipaddress.ip_address(self.client_address[0])
        except ValueError:
            return False
        return any(client_ip in network for network in ALLOWED_NETWORKS)

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
        if ALLOWED_NETWORKS:
            logging.info(
                "Router wake API allowed client networks: %s",
                ", ".join(str(network) for network in ALLOWED_NETWORKS),
            )
        if PC_API_TARGETS:
            logging.info(
                "Router PC API auto-detection targets: %s", ", ".join(PC_API_TARGETS)
            )
        httpd.serve_forever()
