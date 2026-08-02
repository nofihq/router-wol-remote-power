import re
from pathlib import Path
import unittest


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
README = REPOSITORY_ROOT / "README.md"
DOCS = REPOSITORY_ROOT / "docs"
CONFIGURATION_VALUES = DOCS / "configuration-values.md"


class DocumentationConsistencyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.markdown_files = [README, *sorted(DOCS.glob("*.md"))]

    def test_relative_markdown_links_exist(self):
        missing = []
        for path in self.markdown_files:
            contents = path.read_text(encoding="utf-8")
            for target in re.findall(r"\[[^]]+\]\(([^)]+)\)", contents):
                file_target = target.split("#", 1)[0]
                if not file_target or "://" in file_target or file_target.startswith("mailto:"):
                    continue
                if not (path.parent / file_target).resolve().exists():
                    missing.append("{} -> {}".format(path.name, file_target))
        self.assertEqual(missing, [])

    def test_all_named_placeholders_are_defined(self):
        placeholders = set()
        sources = [REPOSITORY_ROOT / ".env.example", *self.markdown_files]
        for path in sources:
            contents = path.read_text(encoding="utf-8")
            placeholders.update(re.findall(r"<([A-Z][A-Z0-9_]+)>", contents))

        configuration = CONFIGURATION_VALUES.read_text(encoding="utf-8")
        defined = set(re.findall(r"`<([A-Z][A-Z0-9_]+)>`", configuration))
        self.assertEqual(sorted(placeholders - defined), [])

    def test_dual_boot_shortcut_contract_is_consistent(self):
        expected = (
            "PC SUSPEND: http://<ROUTER_TAILSCALE_IP>:8080/suspend",
            "PC OFF:     http://<ROUTER_TAILSCALE_IP>:8080/shutdown",
            "PC STATUS:  http://<ROUTER_TAILSCALE_IP>:8080/status",
        )
        for relative_path in (
            "README.md",
            "docs/configuration-values.md",
            "docs/ios-shortcuts.md",
        ):
            contents = (REPOSITORY_ROOT / relative_path).read_text(encoding="utf-8")
            for line in expected:
                self.assertIn(line, contents)

        ios = (DOCS / "ios-shortcuts.md").read_text(encoding="utf-8")
        self.assertIn("Header:     Authorization: Bearer <PC_TOKEN>", ios)
        self.assertIn("Header: Authorization: Bearer <ROUTER_TOKEN>", ios)

    def test_dispatcher_targets_use_router_reachable_placeholders(self):
        sources = [
            REPOSITORY_ROOT / ".env.example",
            DOCS / "setup.md",
            DOCS / "windows-setup.md",
        ]
        combined = "\n".join(path.read_text(encoding="utf-8") for path in sources)
        self.assertNotRegex(
            combined,
            r"PC_API_TARGETS=.*(?:LINUX|WINDOWS)_PC_TAILSCALE_IP",
        )
        self.assertIn("<LINUX_PC_REACHABLE_IP>", combined)
        self.assertIn("<WINDOWS_PC_REACHABLE_IP>", combined)

    def test_windows_dual_boot_requires_shared_pc_token(self):
        contents = (DOCS / "windows-setup.md").read_text(encoding="utf-8")
        self.assertIn("do **not** generate an\nindependent Windows token", contents)
        self.assertIn("http://<ROUTER_TAILSCALE_IP>:8080/shutdown", contents)


if __name__ == "__main__":
    unittest.main()
