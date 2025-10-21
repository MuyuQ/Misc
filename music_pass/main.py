#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
自动点击"领取成功"按钮脚本

该脚本通过Appium远程控制Android设备并自动点击"领取成功"按钮。
支持通过Wi-Fi无线连接到真实Android设备，无需USB直连。
"""

import time
import logging
import argparse
import json
import os
import yaml  # type: ignore
from typing import Optional, List, Dict, Any
from dataclasses import dataclass
from enum import Enum
from appium import webdriver
from appium.webdriver.common.appiumby import AppiumBy
from selenium.common.exceptions import NoSuchElementException, WebDriverException, TimeoutException
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

# 配置常量
class Config:
    """配置常量类"""
    DEFAULT_INTERVAL = 2  # 默认检测间隔(秒)
    DEFAULT_TIMEOUT = 300  # 默认超时时间(秒)
    DEFAULT_DEVICE_PORT = "5555"  # 默认设备端口
    DEFAULT_APPIUM_IP = "127.0.0.1"  # 默认Appium IP
    DEFAULT_APPIUM_PORT = "4723"  # 默认Appium端口
    DEFAULT_BUTTON_TEXT = "领取成功"  # 默认按钮文本
    MAX_RETRIES = 3  # 最大重试次数
    RETRY_DELAY = 1  # 重试延迟(秒)
    SCREENSHOT_DIR = "screenshots"  # 截图保存目录

# 元素定位策略枚举
class LocatorStrategy(Enum):
    """元素定位策略枚举"""
    TEXT = "text"
    ID = "id"
    XPATH = "xpath"
    CLASS_NAME = "class_name"

@dataclass
class AppiumConfig:
    """Appium配置数据类"""
    device_ip: str
    device_port: str = Config.DEFAULT_DEVICE_PORT
    appium_ip: str = Config.DEFAULT_APPIUM_IP
    appium_port: str = Config.DEFAULT_APPIUM_PORT
    app_package: Optional[str] = None
    app_activity: Optional[str] = None
    button_text: str = Config.DEFAULT_BUTTON_TEXT
    interval: int = Config.DEFAULT_INTERVAL
    timeout: int = Config.DEFAULT_TIMEOUT
    debug: bool = False
    button_id: Optional[str] = None
    button_xpath: Optional[str] = None
    screenshot: bool = False
    screenshot_dir: str = Config.SCREENSHOT_DIR
    config_file: Optional[str] = None

# 设置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)


def load_config(config_path):
    """
    加载配置文件（支持JSON和YAML格式）
    """
    if not config_path or not os.path.exists(config_path):
        return {}
    
    try:
        with open(config_path, 'r', encoding='utf-8') as f:
            # 根据文件扩展名选择加载方式
            if config_path.lower().endswith(('.yml', '.yaml')):
                config = yaml.safe_load(f)
            else:
                config = json.load(f)
        logger.info(f"已加载配置文件: {config_path}")
        return config or {}
    except Exception as e:
        logger.error(f"加载配置文件时发生错误: {e}")
        return {}


def parse_arguments():
    """
    解析命令行参数
    """
    parser = argparse.ArgumentParser(description='自动点击"领取成功"按钮脚本')
    parser.add_argument('--device-ip', type=str, required=True, help='Android设备的IP地址')
    parser.add_argument('--device-port', type=str, default='5555', help='Android设备的adb端口，默认为5555')
    parser.add_argument('--appium-ip', type=str, default='127.0.0.1', help='Appium服务器的IP地址，默认为127.0.0.1')
    parser.add_argument('--appium-port', type=str, default='4723', help='Appium服务器的端口，默认为4723')
    parser.add_argument('--app-package', type=str, required=True, help='目标应用的包名')
    parser.add_argument('--app-activity', type=str, required=True, help='目标应用的Activity名')
    parser.add_argument('--button-text', type=str, default='领取成功', help='要点击的按钮文本，默认为"领取成功"')
    parser.add_argument('--button-id', type=str, help='要点击的按钮ID')
    parser.add_argument('--button-xpath', type=str, help='要点击的按钮XPath')
    parser.add_argument('--interval', type=int, default=2, help='检测间隔（秒），默认为2秒')
    parser.add_argument('--timeout', type=int, default=300, help='检测超时时间（秒），默认为300秒，设为0表示不超时')
    parser.add_argument('--screenshot', action='store_true', help='启用截图功能')
    parser.add_argument('--screenshot-dir', type=str, default='screenshots', help='截图保存目录，默认为screenshots')
    parser.add_argument('--config', type=str, help='配置文件路径（支持JSON和YAML格式）')
    parser.add_argument('--debug', action='store_true', help='启用调试模式，输出详细日志')
    return parser.parse_args()


def connect_to_device(args):
    """
    连接到Android设备
    """
    # 使用 capabilities 字典，这是官方推荐的方式
    capabilities = {
        'platformName': 'Android',
        'automationName': 'uiautomator2',
        'deviceName': 'Remote_Device',
        'appPackage': args.app_package,
        'appActivity': args.app_activity,
        'noReset': True,
        'remoteAdbHost': args.device_ip,
        'remoteAdbPort': args.device_port
    }
    
    appium_server_url = f"http://{args.appium_ip}:{args.appium_port}"
    logger.info(f"正在连接到Appium服务器: {appium_server_url}")
    logger.info(f"设备连接信息: {args.device_ip}:{args.device_port}")
    logger.info(f"应用信息: {args.app_package}/{args.app_activity}")
    
    try:
        # 根据官方文档，这是正确的用法，但类型检查器可能有误
        driver = webdriver.Remote(appium_server_url, capabilities)  # type: ignore
        logger.info("成功连接到设备")
        return driver
    except WebDriverException as e:
        logger.error(f"连接设备失败: {e}")
        raise


def take_screenshot(driver, screenshot_dir, attempt_count):
    """
    截取屏幕截图
    """
    try:
        timestamp = time.strftime("%Y%m%d_%H%M%S")
        filename = f"screenshot_{attempt_count}_{timestamp}.png"
        filepath = os.path.join(screenshot_dir, filename)
        driver.save_screenshot(filepath)
        logger.debug(f"已保存截图: {filepath}")
    except Exception as e:
        logger.error(f"截图时发生错误: {e}")


def find_and_click_button(driver, button_text, interval, timeout, button_id=None, button_xpath=None, screenshot=False, screenshot_dir=None):
    """
    查找并点击指定文本的按钮
    支持多种定位策略：文本、ID、XPath
    """
    start_time = time.time()
    attempt_count = 0
    
    logger.info(f"开始自动点击，寻找按钮")
    if button_text:
        logger.info(f"  - 文本: \"{button_text}\"")
    if button_id:
        logger.info(f"  - ID: \"{button_id}\"")
    if button_xpath:
        logger.info(f"  - XPath: \"{button_xpath}\"")
    
    while True:
        attempt_count += 1
        current_time = time.time()
        elapsed_time = current_time - start_time
        
        # 检查是否超时
        if timeout > 0 and elapsed_time > timeout:
            logger.info(f"已达到超时时间 {timeout} 秒，停止点击")
            break
        
        # 如果启用了截图功能，先截图
        if screenshot and screenshot_dir:
            take_screenshot(driver, screenshot_dir, attempt_count)
        
        try:
            elements = []
            
            # 优先使用ID定位
            if button_id:
                logger.debug(f"第 {attempt_count} 次尝试通过ID查找按钮: {button_id}")
                elements = driver.find_elements(AppiumBy.ID, button_id)
            
            # 如果没有找到，尝试XPath定位
            if not elements and button_xpath:
                logger.debug(f"第 {attempt_count} 次尝试通过XPath查找按钮: {button_xpath}")
                elements = driver.find_elements(AppiumBy.XPATH, button_xpath)
            
            # 如果没有找到，尝试文本定位
            if not elements and button_text:
                logger.debug(f"第 {attempt_count} 次尝试通过文本查找按钮: {button_text}")
                elements = driver.find_elements(AppiumBy.ANDROID_UIAUTOMATOR, f'text("{button_text}")')
            
            if elements:
                logger.info(f"找到 {len(elements)} 个匹配的按钮")
                # 点击第一个找到的按钮
                elements[0].click()
                logger.info("已成功点击按钮")
                # 点击成功后截图
                if screenshot and screenshot_dir:
                    take_screenshot(driver, screenshot_dir, f"{attempt_count}_success")
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
    """
    主函数
    """
    args = parse_arguments()
    
    # 加载配置文件
    config = load_config(args.config)
    
    # 设置日志级别
    if args.debug or config.get('debug', False):
        logger.setLevel(logging.DEBUG)
    
    logger.info("开始执行自动点击脚本")
    
    # 如果启用了截图功能，确保截图目录存在
    screenshot_enabled = args.screenshot or config.get('screenshot', False)
    screenshot_dir = args.screenshot_dir or config.get('screenshot_dir', 'screenshots')
    if screenshot_enabled:
        os.makedirs(screenshot_dir, exist_ok=True)
        logger.info(f"截图功能已启用，截图将保存到: {screenshot_dir}")
    
    driver = None  # 初始化driver变量
    try:
        # 连接设备
        driver = connect_to_device(args)
        
        # 获取按钮定位参数（优先使用命令行参数，然后是配置文件）
        button_text = args.button_text if args.button_text else config.get('button_text', '领取成功')
        button_id = args.button_id if args.button_id else config.get('button_id')
        button_xpath = args.button_xpath if args.button_xpath else config.get('button_xpath')
        interval = args.interval if args.interval else config.get('interval', 2)
        timeout = args.timeout if args.timeout else config.get('timeout', 300)
        
        # 查找并点击按钮
        success = find_and_click_button(
            driver, 
            button_text, 
            interval, 
            timeout,
            button_id,
            button_xpath,
            screenshot_enabled,
            screenshot_dir
        )
        
        if success:
            logger.info("执行成功")
        else:
            logger.info("执行结束但未能成功点击按钮")
    
    except Exception as e:
        logger.error(f"执行过程中发生错误: {e}")
    
    finally:
        # 确保关闭driver
        if driver is not None:
            try:
                driver.quit()
                logger.info("已关闭设备连接")
            except Exception as e:
                logger.error(f"关闭设备连接时发生错误: {e}")


if __name__ == "__main__":
    main()