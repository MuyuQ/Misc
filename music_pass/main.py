#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
自动点击"领取成功"按钮脚本

该脚本通过Appium远程控制Android设备并自动点击"领取成功"按钮。
支持通过Wi-Fi无线连接到真实Android设备，无需USB直连。
"""

import time
import signal
import logging
import argparse
import json
import os
from typing import Optional

try:
    import yaml
except ImportError:
    yaml = None  # type: ignore

from appium import webdriver
from appium.webdriver.common.appiumby import AppiumBy
from selenium.common.exceptions import NoSuchElementException, WebDriverException

# 配置常量
DEFAULT_INTERVAL = 2
DEFAULT_TIMEOUT = 300
DEFAULT_DEVICE_PORT = "5555"
DEFAULT_APPIUM_IP = "127.0.0.1"
DEFAULT_APPIUM_PORT = "4723"
DEFAULT_BUTTON_TEXT = "领取成功"
MAX_RETRIES = 3
RETRY_DELAY = 1
SCREENSHOT_DIR = "screenshots"

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

# 优雅退出标志
_shutdown_requested = False


def _signal_handler(signum, frame):
    """处理 SIGINT 信号，设置退出标志"""
    global _shutdown_requested
    _shutdown_requested = True
    logger.info("收到中断信号，正在优雅退出...")


signal.signal(signal.SIGINT, _signal_handler)


def load_config(config_path: str) -> dict:
    """加载配置文件（支持JSON和YAML格式）"""
    if not config_path or not os.path.exists(config_path):
        return {}

    try:
        with open(config_path, 'r', encoding='utf-8') as f:
            if config_path.lower().endswith(('.yml', '.yaml')):
                if yaml is None:
                    logger.error("未安装 PyYAML，无法加载 YAML 配置文件")
                    return {}
                config = yaml.safe_load(f)
            else:
                config = json.load(f)
        logger.info(f"已加载配置文件: {config_path}")
        return config or {}
    except Exception as e:
        logger.error(f"加载配置文件时发生错误: {e}")
        return {}


def merge_config(args, file_config: dict) -> dict:
    """合并命令行参数和配置文件，命令行参数优先"""
    return {
        'device_ip': args.device_ip,
        'device_port': args.device_port if args.device_port is not None else file_config.get('device_port', DEFAULT_DEVICE_PORT),
        'appium_ip': args.appium_ip if args.appium_ip is not None else file_config.get('appium_ip', DEFAULT_APPIUM_IP),
        'appium_port': args.appium_port if args.appium_port is not None else file_config.get('appium_port', DEFAULT_APPIUM_PORT),
        'app_package': args.app_package,
        'app_activity': args.app_activity,
        'button_text': args.button_text if args.button_text is not None else file_config.get('button_text', DEFAULT_BUTTON_TEXT),
        'button_id': args.button_id if args.button_id is not None else file_config.get('button_id'),
        'button_xpath': args.button_xpath if args.button_xpath is not None else file_config.get('button_xpath'),
        'interval': args.interval if args.interval is not None else file_config.get('interval', DEFAULT_INTERVAL),
        'timeout': args.timeout if args.timeout is not None else file_config.get('timeout', DEFAULT_TIMEOUT),
        'screenshot': args.screenshot or file_config.get('screenshot', False),
        'screenshot_dir': args.screenshot_dir if args.screenshot_dir is not None else file_config.get('screenshot_dir', SCREENSHOT_DIR),
        'debug': args.debug or file_config.get('debug', False),
    }


def parse_arguments():
    """解析命令行参数"""
    parser = argparse.ArgumentParser(description='自动点击"领取成功"按钮脚本')
    parser.add_argument('--device-ip', type=str, required=True, help='Android设备的IP地址')
    parser.add_argument('--device-port', type=str, default=None, help='Android设备的adb端口，默认为5555')
    parser.add_argument('--appium-ip', type=str, default=None, help='Appium服务器的IP地址，默认为127.0.0.1')
    parser.add_argument('--appium-port', type=str, default=None, help='Appium服务器的端口，默认为4723')
    parser.add_argument('--app-package', type=str, required=True, help='目标应用的包名')
    parser.add_argument('--app-activity', type=str, required=True, help='目标应用的Activity名')
    parser.add_argument('--button-text', type=str, default=None, help='要点击的按钮文本，默认为"领取成功"')
    parser.add_argument('--button-id', type=str, default=None, help='要点击的按钮ID')
    parser.add_argument('--button-xpath', type=str, default=None, help='要点击的按钮XPath')
    parser.add_argument('--interval', type=int, default=None, help='检测间隔（秒），默认为2秒')
    parser.add_argument('--timeout', type=int, default=None, help='检测超时时间（秒），默认为300秒，设为0表示不超时')
    parser.add_argument('--screenshot', action='store_true', help='启用截图功能')
    parser.add_argument('--screenshot-dir', type=str, default=None, help='截图保存目录，默认为screenshots')
    parser.add_argument('--config', type=str, help='配置文件路径（支持JSON和YAML格式）')
    parser.add_argument('--debug', action='store_true', help='启用调试模式，输出详细日志')
    return parser.parse_args()


def connect_to_device(cfg: dict):
    """连接到Android设备，支持重试"""
    capabilities = {
        'platformName': 'Android',
        'automationName': 'uiautomator2',
        'deviceName': 'Remote_Device',
        'appPackage': cfg['app_package'],
        'appActivity': cfg['app_activity'],
        'noReset': True,
        'remoteAdbHost': cfg['device_ip'],
        'remoteAdbPort': cfg['device_port']
    }

    appium_server_url = f"http://{cfg['appium_ip']}:{cfg['appium_port']}"
    logger.info(f"正在连接到Appium服务器: {appium_server_url}")
    logger.info(f"设备连接信息: {cfg['device_ip']}:{cfg['device_port']}")
    logger.info(f"应用信息: {cfg['app_package']}/{cfg['app_activity']}")

    for attempt in range(1, MAX_RETRIES + 1):
        try:
            driver = webdriver.Remote(appium_server_url, capabilities)  # type: ignore
            logger.info("成功连接到设备")
            return driver
        except WebDriverException as e:
            if attempt < MAX_RETRIES:
                logger.warning(f"连接失败（第 {attempt}/{MAX_RETRIES} 次），{RETRY_DELAY} 秒后重试: {e}")
                time.sleep(RETRY_DELAY)
            else:
                logger.error(f"连接失败，已重试 {MAX_RETRIES} 次: {e}")
                raise


def take_screenshot(driver, screenshot_dir: str, tag: str):
    """截取屏幕截图"""
    try:
        timestamp = time.strftime("%Y%m%d_%H%M%S")
        filepath = os.path.join(screenshot_dir, f"screenshot_{tag}_{timestamp}.png")
        driver.save_screenshot(filepath)
        logger.debug(f"已保存截图: {filepath}")
    except Exception as e:
        logger.error(f"截图时发生错误: {e}")


def find_and_click_button(driver, cfg: dict) -> bool:
    """查找并点击指定文本的按钮，支持多种定位策略：ID > XPath > 文本"""
    start_time = time.time()
    attempt_count = 0
    screenshot_seq = 0
    button_text = cfg['button_text']
    button_id = cfg['button_id']
    button_xpath = cfg['button_xpath']
    interval = cfg['interval']
    timeout = cfg['timeout']
    screenshot_enabled = cfg['screenshot']
    screenshot_dir = cfg['screenshot_dir']

    logger.info("开始自动点击，寻找按钮")
    if button_text:
        logger.info(f"  - 文本: \"{button_text}\"")
    if button_id:
        logger.info(f"  - ID: \"{button_id}\"")
    if button_xpath:
        logger.info(f"  - XPath: \"{button_xpath}\"")

    while not _shutdown_requested:
        attempt_count += 1
        elapsed_time = time.time() - start_time

        if timeout > 0 and elapsed_time > timeout:
            logger.info(f"已达到超时时间 {timeout} 秒，停止点击")
            break

        if screenshot_enabled:
            screenshot_seq += 1
            take_screenshot(driver, screenshot_dir, f"{screenshot_seq:04d}")

        try:
            elements = []

            if button_id:
                logger.debug(f"第 {attempt_count} 次尝试通过ID查找按钮: {button_id}")
                elements = driver.find_elements(AppiumBy.ID, button_id)

            if not elements and button_xpath:
                logger.debug(f"第 {attempt_count} 次尝试通过XPath查找按钮: {button_xpath}")
                elements = driver.find_elements(AppiumBy.XPATH, button_xpath)

            if not elements and button_text:
                logger.debug(f"第 {attempt_count} 次尝试通过文本查找按钮: {button_text}")
                elements = driver.find_elements(AppiumBy.ANDROID_UIAUTOMATOR, f'text("{button_text}")')

            if elements:
                logger.info(f"找到 {len(elements)} 个匹配的按钮")
                elements[0].click()
                logger.info("已成功点击按钮")
                if screenshot_enabled:
                    take_screenshot(driver, screenshot_dir, f"{screenshot_seq:04d}_success")
                return True
            else:
                logger.debug(f"未找到按钮，{interval} 秒后重试...")
                time.sleep(interval)

        except NoSuchElementException:
            logger.debug(f"未找到按钮，{interval} 秒后重试...")
            time.sleep(interval)
        except Exception as e:
            logger.error(f"查找按钮时发生错误: {e}")
            time.sleep(interval)

    logger.info(f"自动点击结束，总共尝试了 {attempt_count} 次")
    return False


def main():
    """主函数"""
    args = parse_arguments()

    file_config = load_config(args.config)
    cfg = merge_config(args, file_config)

    if cfg['debug']:
        logger.setLevel(logging.DEBUG)

    logger.info("开始执行自动点击脚本")

    if cfg['screenshot']:
        os.makedirs(cfg['screenshot_dir'], exist_ok=True)
        logger.info(f"截图功能已启用，截图将保存到: {cfg['screenshot_dir']}")

    driver = None
    try:
        driver = connect_to_device(cfg)
        success = find_and_click_button(driver, cfg)

        if success:
            logger.info("执行成功")
        else:
            logger.info("执行结束但未能成功点击按钮")

    except Exception as e:
        logger.error(f"执行过程中发生错误: {e}")

    finally:
        if driver is not None:
            try:
                driver.quit()
                logger.info("已关闭设备连接")
            except Exception as e:
                logger.error(f"关闭设备连接时发生错误: {e}")


if __name__ == "__main__":
    main()
