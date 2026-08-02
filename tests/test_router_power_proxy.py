import importlib.util
import os
from pathlib import Path
import tempfile
import unittest
import urllib.error
from unittest import mock


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
ROUTER_API = REPOSITORY_ROOT / "router" / "router_wake.py"


class FakeResponse:
    def __init__(self, body="ON", status=200):
        self._body = body.encode("utf-8")
        self.status = status

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return False

    def read(self, _limit):
        return self._body


class RouterPowerProxyTests(unittest.TestCase):
    def setUp(self):
        self.temp_directory = tempfile.TemporaryDirectory()
        temp_path = Path(self.temp_directory.name)
        self.router_token_file = temp_path / "router-token"
        self.pc_token_file = temp_path / "pc-token"
        self.router_token_file.write_text(
            "router-test-token-with-enough-characters", encoding="utf-8"
        )
        self.pc_token_file.write_text(
            "pc-test-token-with-enough-characters", encoding="utf-8"
        )

        environment = {
            "AUTH_TOKEN_FILE": str(self.router_token_file),
            "PC_AUTH_TOKEN_FILE": str(self.pc_token_file),
            "PC_API_TARGETS": "http://linux-pc:8081,http://windows-pc:8081",
            "PC_API_TIMEOUT_SECONDS": "0.2",
            "WOL_TARGET_MAC": "00:11:22:33:44:55",
        }
        with mock.patch.dict(os.environ, environment, clear=True):
            spec = importlib.util.spec_from_file_location(
                "router_wake_under_test_{}".format(id(self)), ROUTER_API
            )
            self.module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(self.module)

    def tearDown(self):
        self.temp_directory.cleanup()

    def make_handler(self, path, token):
        handler = object.__new__(self.module.Handler)
        handler.path = path
        handler.headers = {"Authorization": "Bearer {}".format(token)}
        handler.client_address = ("100.64.0.10", 12345)
        handler._respond = mock.Mock()
        return handler

    def test_tries_the_second_os_when_the_first_is_offline(self):
        with mock.patch.object(
            self.module.urllib.request,
            "urlopen",
            side_effect=[
                urllib.error.URLError("Linux offline"),
                FakeResponse("Suspending..."),
            ],
        ) as urlopen:
            code, body = self.module._proxy_to_active_pc("/suspend")

        self.assertEqual((code, body), (200, "Suspending..."))
        self.assertEqual(urlopen.call_count, 2)
        second_request = urlopen.call_args_list[1].args[0]
        self.assertEqual(second_request.full_url, "http://windows-pc:8081/suspend")
        self.assertEqual(
            second_request.headers["Authorization"],
            "Bearer pc-test-token-with-enough-characters",
        )

    def test_returns_service_unavailable_when_both_operating_systems_are_offline(self):
        with mock.patch.object(
            self.module.urllib.request,
            "urlopen",
            side_effect=urllib.error.URLError("offline"),
        ):
            result = self.module._proxy_to_active_pc("/status")

        self.assertEqual(result, (503, "No active PC OS API found"))

    def test_rejects_invalid_target_urls(self):
        with self.assertRaises(SystemExit):
            self.module._parse_pc_api_targets("https://public.example:8081")
        with self.assertRaises(SystemExit):
            self.module._parse_pc_api_targets("http://host-without-port")
        with self.assertRaises(SystemExit):
            self.module._parse_pc_api_targets("http://user:password@host:8081")

    def test_empty_target_list_preserves_wake_only_mode(self):
        self.assertEqual(self.module._parse_pc_api_targets(""), [])

    def test_handler_routes_power_action_with_pc_token(self):
        handler = self.make_handler(
            "/shutdown", "pc-test-token-with-enough-characters"
        )
        with mock.patch.object(
            self.module, "_proxy_to_active_pc", return_value=(200, "Shutting down...")
        ) as proxy:
            handler.do_GET()

        proxy.assert_called_once_with("/shutdown")
        handler._respond.assert_called_once_with(200, "Shutting down...")

    def test_existing_wake_route_still_uses_router_token(self):
        handler = self.make_handler(
            "/wake", "router-test-token-with-enough-characters"
        )
        with mock.patch.object(self.module.subprocess, "run") as run:
            handler.do_GET()

        run.assert_called_once_with(
            [
                self.module.ETHER_WAKE,
                "-i",
                self.module.WOL_INTERFACE,
                "-b",
                self.module.WOL_TARGET_MAC,
            ],
            check=True,
        )
        handler._respond.assert_called_once_with(200, "Wake packet sent")


if __name__ == "__main__":
    unittest.main()
