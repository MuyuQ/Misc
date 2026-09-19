import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class DailyScriptsCommonTests(unittest.TestCase):
    def test_shared_common_library_exists_with_required_functions(self):
        common_path = ROOT / "日常脚本" / "lib" / "common.sh"

        self.assertTrue(common_path.exists(), "日常脚本/lib/common.sh is required by every script")
        content = common_path.read_text(encoding="utf-8")
        for function_name in [
            "load_env",
            "require_cmd",
            "exit_missing_dep",
            "print_json",
            "print_human",
            "notify_email",
            "hostname_short",
        ]:
            self.assertIn(f"{function_name}()", content)

    def test_all_daily_scripts_source_the_shared_common_library(self):
        scripts_dir = ROOT / "日常脚本" / "scripts"
        scripts = sorted(scripts_dir.glob("*.sh"))

        self.assertEqual(len(scripts), 50)
        for script in scripts:
            content = script.read_text(encoding="utf-8")
            self.assertIn('../lib/common.sh"', content, script.name)


if __name__ == "__main__":
    unittest.main()
