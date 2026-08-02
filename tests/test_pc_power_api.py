import importlib.util
import os
from pathlib import Path
import tempfile
import unittest
from unittest import mock


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
PC_API = REPOSITORY_ROOT / "pc" / "pc_power_api.py"


def load_api(environment):
    with mock.patch.dict(os.environ, environment, clear=True):
        spec = importlib.util.spec_from_file_location(
            "pc_power_api_under_test_{}".format(id(environment)), PC_API
        )
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module


class PcPowerApiTests(unittest.TestCase):
    def setUp(self):
        self.temp_directory = tempfile.TemporaryDirectory()
        self.token_file = Path(self.temp_directory.name) / "token"
        self.token_file.write_text(
            "pc-test-token-with-enough-characters", encoding="utf-8"
        )
        self.environment = {
            "AUTH_TOKEN_FILE": str(self.token_file),
            "PC_LISTEN_IP": "0.0.0.0",
            "PC_ALLOWED_CLIENT_NETS": "100.64.0.0/10,192.168.1.1/32",
        }

    def tearDown(self):
        self.temp_directory.cleanup()

    def make_handler(self, module, source_ip, path="/status"):
        handler = object.__new__(module.Handler)
        handler.path = path
        handler.client_address = (source_ip, 12345)
        handler.headers = {
            "Authorization": "Bearer pc-test-token-with-enough-characters"
        }
        handler._respond = mock.Mock()
        return handler

    def test_router_and_tailnet_sources_are_allowed(self):
        module = load_api(self.environment)
        for source_ip in ("192.168.1.1", "100.64.0.10"):
            handler = self.make_handler(module, source_ip)
            handler.do_GET()
            handler._respond.assert_called_once_with(200, "ON")

    def test_other_lan_clients_are_rejected(self):
        module = load_api(self.environment)
        handler = self.make_handler(module, "192.168.1.50")
        handler.do_GET()
        handler._respond.assert_called_once_with(403, "Forbidden")

    def test_wildcard_listener_requires_an_allowlist(self):
        environment = dict(self.environment)
        environment["PC_ALLOWED_CLIENT_NETS"] = ""
        with self.assertRaises(SystemExit):
            load_api(environment)

    def test_invalid_allowlist_entry_is_rejected(self):
        environment = dict(self.environment)
        environment["PC_ALLOWED_CLIENT_NETS"] = "not-a-network"
        with self.assertRaises(SystemExit):
            load_api(environment)


if __name__ == "__main__":
    unittest.main()
