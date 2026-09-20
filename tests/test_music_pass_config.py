import importlib.util
import json
import sys
import tempfile
import types
import unittest
from pathlib import Path
from unittest.mock import Mock, patch


ROOT = Path(__file__).resolve().parents[1]
MAIN_PATH = ROOT / "music_pass" / "main.py"


def install_mobile_stubs(include_yaml=True):
    """install_mobile_stubs 功能说明。"""
    appium = types.ModuleType("appium")
    appium.webdriver = types.SimpleNamespace(Remote=Mock())
    sys.modules["appium"] = appium

    appiumby = types.ModuleType("appium.webdriver.common.appiumby")

    class AppiumBy:
        ANDROID_UIAUTOMATOR = "android_uiautomator"
        CLASS_NAME = "class_name"
        ID = "id"
        XPATH = "xpath"

    appiumby.AppiumBy = AppiumBy
    sys.modules["appium.webdriver"] = types.ModuleType("appium.webdriver")
    sys.modules["appium.webdriver.common"] = types.ModuleType("appium.webdriver.common")
    sys.modules["appium.webdriver.common.appiumby"] = appiumby

    exceptions = types.ModuleType("selenium.common.exceptions")

    class NoSuchElementException(Exception):
        pass

    class WebDriverException(Exception):
        pass

    class TimeoutException(Exception):
        pass

    exceptions.NoSuchElementException = NoSuchElementException
    exceptions.WebDriverException = WebDriverException
    exceptions.TimeoutException = TimeoutException
    sys.modules["selenium"] = types.ModuleType("selenium")
    sys.modules["selenium.common"] = types.ModuleType("selenium.common")
    sys.modules["selenium.common.exceptions"] = exceptions

    ui = types.ModuleType("selenium.webdriver.support.ui")
    ui.WebDriverWait = object
    sys.modules["selenium.webdriver"] = types.ModuleType("selenium.webdriver")
    sys.modules["selenium.webdriver.support"] = types.ModuleType("selenium.webdriver.support")
    sys.modules["selenium.webdriver.support.ui"] = ui
    sys.modules["selenium.webdriver.support.expected_conditions"] = types.ModuleType(
        "selenium.webdriver.support.expected_conditions"
    )

    if include_yaml:
        yaml_module = types.ModuleType("yaml")
        yaml_module.safe_load = lambda stream: {}
        sys.modules["yaml"] = yaml_module
    else:
        sys.modules.pop("yaml", None)


def import_main(include_yaml=True):
    """import_main 功能说明。"""
    install_mobile_stubs(include_yaml=include_yaml)
    sys.modules.pop("music_pass_main_under_test", None)
    spec = importlib.util.spec_from_file_location("music_pass_main_under_test", MAIN_PATH)
    module = importlib.util.module_from_spec(spec)
    sys.modules["music_pass_main_under_test"] = module
    spec.loader.exec_module(module)
    return module


class MusicPassConfigTests(unittest.TestCase):
    """MusicPassConfigTests 功能说明。"""
    def test_json_config_loads_without_pyyaml_installed(self):
        module = import_main(include_yaml=False)

        with tempfile.TemporaryDirectory() as tmp:
            config_path = Path(tmp) / "config.json"
            config_path.write_text(json.dumps({"device_ip": "192.168.1.50"}), encoding="utf-8")

            self.assertEqual(module.load_config(str(config_path)), {"device_ip": "192.168.1.50"})

    def test_config_file_supplies_required_connection_fields(self):
        module = import_main()

        with tempfile.TemporaryDirectory() as tmp:
            config_path = Path(tmp) / "config.json"
            config_path.write_text(
                json.dumps(
                    {
                        "device_ip": "192.168.1.100",
                        "app_package": "com.example.app",
                        "app_activity": "com.example.app.MainActivity",
                        "button_text": "配置按钮",
                        "interval": 7,
                    }
                ),
                encoding="utf-8",
            )

            with patch.object(sys, "argv", ["main.py", "--config", str(config_path)]):
                args = module.parse_arguments()

            runtime_config = module.build_appium_config(args, module.load_config(args.config))

        self.assertEqual(runtime_config.device_ip, "192.168.1.100")
        self.assertEqual(runtime_config.app_package, "com.example.app")
        self.assertEqual(runtime_config.app_activity, "com.example.app.MainActivity")
        self.assertEqual(runtime_config.button_text, "配置按钮")
        self.assertEqual(runtime_config.interval, 7)

    def test_cli_values_override_config_file_values(self):
        module = import_main()

        with tempfile.TemporaryDirectory() as tmp:
            config_path = Path(tmp) / "config.json"
            config_path.write_text(
                json.dumps(
                    {
                        "device_ip": "192.168.1.100",
                        "app_package": "com.example.app",
                        "app_activity": "com.example.app.MainActivity",
                        "interval": 7,
                    }
                ),
                encoding="utf-8",
            )

            with patch.object(
                sys,
                "argv",
                [
                    "main.py",
                    "--config",
                    str(config_path),
                    "--device-ip",
                    "10.0.0.2",
                    "--app-package",
                    "com.cli.app",
                    "--app-activity",
                    "com.cli.app.MainActivity",
                    "--interval",
                    "3",
                ],
            ):
                args = module.parse_arguments()

            runtime_config = module.build_appium_config(args, module.load_config(args.config))

        self.assertEqual(runtime_config.device_ip, "10.0.0.2")
        self.assertEqual(runtime_config.app_package, "com.cli.app")
        self.assertEqual(runtime_config.app_activity, "com.cli.app.MainActivity")
        self.assertEqual(runtime_config.interval, 3)


if __name__ == "__main__":
    unittest.main()
