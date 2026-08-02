import subprocess
from pathlib import Path
import unittest


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
SUSPEND_HELPER = REPOSITORY_ROOT / "pc" / "helpers" / "pc_suspend_with_wol"
SLEEP_HOOK = REPOSITORY_ROOT / "pc" / "helpers" / "phone-wol-power-system-sleep"
INSTALLER = REPOSITORY_ROOT / "scripts" / "install_suspend_api_helper.sh"


class LinuxSuspendHelperTests(unittest.TestCase):
    def test_shell_files_parse(self):
        for path in (SUSPEND_HELPER, SLEEP_HOOK, INSTALLER):
            subprocess.run(["sh", "-n", str(path)], check=True)

    def test_suspend_helper_does_not_manage_modules_after_systemctl(self):
        contents = SUSPEND_HELPER.read_text(encoding="utf-8")
        self.assertNotIn("modprobe", contents)
        self.assertIn("exec /usr/bin/systemctl suspend", contents)

    def test_system_sleep_hook_owns_driver_lifecycle(self):
        contents = SLEEP_HOOK.read_text(encoding="utf-8")
        self.assertIn("pre/*", contents)
        self.assertIn("post/*", contents)
        self.assertIn("/sbin/modprobe -r", contents)
        self.assertIn("/sbin/modprobe", contents)

    def test_required_module_guard_covers_api_and_local_sleep(self):
        helper = SUSPEND_HELPER.read_text(encoding="utf-8")
        hook = SLEEP_HOOK.read_text(encoding="utf-8")
        self.assertIn("SUSPEND_REQUIRE_LOADED_MODULES", helper)
        self.assertIn("SUSPEND_REQUIRE_LOADED_MODULES", hook)

    def test_installer_deploys_the_system_sleep_hook(self):
        contents = INSTALLER.read_text(encoding="utf-8")
        self.assertIn("phone-wol-power-system-sleep", contents)
        self.assertIn("/usr/lib/systemd/system-sleep", contents)


if __name__ == "__main__":
    unittest.main()
