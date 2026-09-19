#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
ADB控制脚本 - 用于通过ADB命令控制Android设备

该脚本提供了一系列函数，用于执行常见的ADB操作，如滑动屏幕、点击屏幕、文本输入等。
主要用于自动化测试或重复性操作。支持多种设备操作和灵活的配置参数。

使用方法:
    python adb_control.py [循环次数]
    
示例:
    python adb_control.py 100  # 执行100次操作循环
    python adb_control.py      # 使用默认循环次数(300次)

作者: Mcode
日期: 2025-09-25
"""


import subprocess
import time
import sys  # 用于sys.exit()和命令行参数处理
import logging
import argparse  # 优化1: 添加argparse模块支持更好的命令行参数处理 (2025-09-25)
from typing import Optional, Tuple, List


# ==================== 配置参数 ====================
class Config:
    """
    配置类 - 集中管理脚本的各种配置参数
    
    该类包含了脚本运行所需的所有配置参数，便于统一管理和修改。
    可以根据不同的设备和使用场景调整这些参数。
    """
    
    # 默认循环次数
    DEFAULT_REPEAT_COUNT = 300
    
    # 时间间隔配置（单位：秒）
    DEVICE_READY_WAIT = 2.0      # 设备准备等待时间
    ANIMATION_WAIT = 1.0         # 动画完成等待时间
    OPERATION_INTERVAL = 0.5     # 操作间隔时间
    CLICK_INTERVAL = 1.0         # 点击操作间隔时间
    
    # 滑动操作配置
    DEFAULT_SWIPE_DURATION = 300  # 默认滑动持续时间（毫秒）
    
    # 屏幕分辨率配置（可根据实际设备调整）
    SCREEN_WIDTH = 1080
    SCREEN_HEIGHT = 1920
    
    # 预定义的操作坐标（可根据具体应用调整）
    SWIPE_COORDINATES = {
        'start': (1000, 1400),
        'end': (540, 1400)
    }
    
    CLICK_COORDINATES = [
        (1126, 1466),
        (770, 2300),
        (939, 2525)
    ]


# ==================== 日志配置 ====================
def setup_logging():
    """
    配置日志系统
    
    设置日志格式和级别，便于调试和问题追踪。
    日志将同时输出到控制台，包含时间戳和日志级别信息。
    """
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )


# ==================== 核心ADB操作函数 ====================
def run_adb_command(command: str, timeout: int = 30) -> Optional[str]:
    """
    执行ADB命令并返回结果
    
    这是所有ADB操作的基础函数，负责执行具体的ADB命令并处理可能的错误。
    使用subprocess模块确保命令执行的安全性和稳定性。
    
    参数:
        command (str): 要执行的ADB命令（不包含'adb'前缀）
        timeout (int): 命令执行超时时间（秒），默认30秒
        
    返回:
        str: 命令执行的输出结果，如果成功的话
        None: 如果命令执行失败或超时
        
    异常处理:
        - CalledProcessError: ADB命令执行失败
        - TimeoutExpired: 命令执行超时
        - Exception: 其他未预期的错误
    """
    full_command = f"adb {command}"
    logging.info(f"执行ADB命令: {full_command}")
    
    try:
        # 使用subprocess执行ADB命令，设置超时和错误处理
        result = subprocess.run(
            full_command, 
            shell=True, 
            check=True,
            stdout=subprocess.PIPE, 
            stderr=subprocess.PIPE, 
            text=True,
            timeout=timeout
        )
        
        if result.stdout.strip():
            logging.debug(f"命令输出: {result.stdout.strip()}")
        
        return result.stdout
        
    except subprocess.CalledProcessError as e:
        error_msg = f"ADB命令执行失败: {e}"
        if e.stderr:
            error_msg += f"\n错误详情: {e.stderr.strip()}"
        logging.error(error_msg)
        return None
        
    except subprocess.TimeoutExpired:
        logging.error(f"ADB命令执行超时 (>{timeout}秒): {full_command}")
        return None
        
    except Exception as e:
        logging.error(f"执行ADB命令时发生未知错误: {e}")
        return None


def check_device_connected() -> bool:
    """
    检查是否有设备连接到ADB
    
    通过执行'adb devices'命令来检测当前连接的Android设备。
    该函数会解析命令输出，统计连接的设备数量并显示设备信息。
    
    返回:
        bool: 如果有设备连接则返回True，否则返回False
        
    注意:
        - 设备必须已启用USB调试模式
        - 设备状态应为'device'而非'unauthorized'或'offline'
    """
    logging.info("检查设备连接状态...")
    result = run_adb_command("devices")
    
    if not result:
        logging.error("无法执行adb devices命令，请检查ADB是否正确安装")
        return False
    
    # 解析设备列表（跳过第一行标题"List of devices attached"）
    lines = result.strip().split('\n')
    if len(lines) <= 1:
        logging.warning("没有检测到已连接的设备")
        logging.info("\n请确保:")
        logging.info("1. 设备已通过USB连接到计算机")
        logging.info("2. 设备已启用USB调试模式")
        logging.info("3. 已授权计算机进行USB调试")
        logging.info("4. ADB驱动程序已正确安装")
        return False
    
    # 提取有效的设备信息
    devices = []
    for line in lines[1:]:
        if line.strip() and '\t' in line:
            device_id, status = line.split('\t', 1)
            devices.append((device_id.strip(), status.strip()))
    
    if not devices:
        logging.warning("没有检测到有效的设备连接")
        return False
    
    # 显示设备信息
    logging.info(f"检测到 {len(devices)} 个已连接设备:")
    for device_id, status in devices:
        status_desc = {
            'device': '已连接并授权',
            'unauthorized': '未授权',
            'offline': '离线'
        }.get(status, status)
        logging.info(f"  - 设备ID: {device_id}, 状态: {status_desc}")
    
    # 检查是否有可用设备
    available_devices = [d for d in devices if d[1] == 'device']
    if not available_devices:
        logging.error("没有可用的设备（所有设备都未授权或离线）")
        return False
    
    return True


# ==================== 设备操作函数 ====================
def swipe_screen(start_x: int, start_y: int, end_x: int, end_y: int, 
                duration: int = None) -> bool:
    """
    在屏幕上从起始坐标滑动到结束坐标
    
    执行屏幕滑动操作，常用于页面滚动、切换界面等场景。
    支持自定义滑动持续时间以控制滑动速度。
    
    参数:
        start_x (int): 起始点X坐标（像素）
        start_y (int): 起始点Y坐标（像素）
        end_x (int): 结束点X坐标（像素）
        end_y (int): 结束点Y坐标（像素）
        duration (int, optional): 滑动持续时间（毫秒），默认使用配置值
        
    返回:
        bool: 操作是否成功执行
        
    示例:
        # 从右向左滑动（常用于返回上一页）
        swipe_screen(900, 500, 100, 500)
        
        # 从下向上滑动（常用于向上滚动）
        swipe_screen(500, 1500, 500, 500, 500)
    """
    if duration is None:
        duration = Config.DEFAULT_SWIPE_DURATION
    
    # 参数验证
    if not all(isinstance(coord, int) and coord >= 0 
               for coord in [start_x, start_y, end_x, end_y]):
        logging.error("滑动坐标必须为非负整数")
        return False
    
    if duration <= 0:
        logging.error("滑动持续时间必须为正数")
        return False
    
    command = f"shell input swipe {start_x} {start_y} {end_x} {end_y} {duration}"
    logging.info(f"执行滑动操作: 从 ({start_x}, {start_y}) 到 ({end_x}, {end_y}), 持续时间: {duration}ms")
    
    result = run_adb_command(command)
    return result is not None


def tap_screen(x: int, y: int) -> bool:
    """
    点击屏幕上的指定坐标
    
    执行单次点击操作，用于模拟用户触摸屏幕。
    常用于点击按钮、选择选项、激活控件等场景。
    
    参数:
        x (int): 点击位置的X坐标（像素）
        y (int): 点击位置的Y坐标（像素）
        
    返回:
        bool: 操作是否成功执行
        
    注意:
        - 坐标系原点(0,0)位于屏幕左上角
        - 确保坐标在屏幕范围内，避免点击无效区域
        - 某些应用可能需要等待界面加载完成后再点击
    """
    # 参数验证
    if not isinstance(x, int) or not isinstance(y, int) or x < 0 or y < 0:
        logging.error("点击坐标必须为非负整数")
        return False
    
    command = f"shell input tap {x} {y}"
    logging.info(f"执行点击操作: 坐标 ({x}, {y})")
    
    result = run_adb_command(command)
    return result is not None


def input_text(text: str) -> bool:
    """
    在当前焦点位置输入文本
    
    向当前具有输入焦点的控件输入文本内容。
    自动处理特殊字符的转义，确保文本能够正确输入。
    
    参数:
        text (str): 要输入的文本内容
        
    返回:
        bool: 操作是否成功执行
        
    注意:
        - 输入前确保目标输入框已获得焦点
        - 特殊字符会被自动转义处理
        - 某些应用可能对输入内容有格式限制
        
    支持的特殊字符转义:
        - 空格 → %s
        - 单引号 → \'
        - 双引号 → \"
    """
    if not isinstance(text, str):
        logging.error("输入文本必须为字符串类型")
        return False
    
    if not text.strip():
        logging.warning("输入文本为空，跳过操作")
        return True
    
    # 对特殊字符进行转义处理
    escaped_text = (
        text.replace(" ", "%s")           # 空格转义
            .replace("'", "\'")
            .replace('"', '\\"')          # 双引号转义
            .replace("&", "\\&")           # &符号转义
            .replace("(", "\\(")           # 括号转义
            .replace(")", "\\)")
    )
    
    command = f"shell input text '{escaped_text}'"
    logging.info(f"执行文本输入: '{text}' (转义后: '{escaped_text}')")
    
    result = run_adb_command(command)
    return result is not None


def press_key(keycode: int) -> bool:
    """
    模拟按键操作
    
    发送指定的按键事件到Android设备，用于模拟物理按键或虚拟按键的操作。
    
    参数:
        keycode (int): 按键代码，Android KeyEvent常量
        
    返回:
        bool: 操作是否成功执行
        
    常用按键代码:
        - 3: HOME键（返回主屏幕）
        - 4: BACK键（返回上一页）
        - 26: POWER键（电源键）
        - 24: VOLUME_UP（音量+）
        - 25: VOLUME_DOWN（音量-）
        - 82: MENU键（菜单键）
        - 84: SEARCH键（搜索键）
        - 66: ENTER键（确认键）
        - 67: DEL键（删除键）
        
    示例:
        press_key(4)   # 按返回键
        press_key(3)   # 按HOME键
        press_key(66)  # 按确认键
    """
    if not isinstance(keycode, int) or keycode < 0:
        logging.error("按键代码必须为非负整数")
        return False
    
    # 常用按键代码映射（用于日志显示）
    key_names = {
        3: "HOME", 4: "BACK", 26: "POWER", 24: "VOLUME_UP", 
        25: "VOLUME_DOWN", 82: "MENU", 84: "SEARCH", 
        66: "ENTER", 67: "DEL"
    }
    
    key_name = key_names.get(keycode, f"KEYCODE_{keycode}")
    command = f"shell input keyevent {keycode}"
    logging.info(f"执行按键操作: {key_name} (keycode: {keycode})")
    
    result = run_adb_command(command)
    return result is not None


# ==================== 高级操作函数 ====================
def perform_click_sequence(coordinates: List[Tuple[int, int]], 
                          interval: float = None) -> bool:
    """
    执行一系列点击操作
    
    按顺序执行多个点击操作，每次点击之间有指定的时间间隔。
    适用于需要连续点击多个位置的自动化场景。
    
    参数:
        coordinates (List[Tuple[int, int]]): 点击坐标列表，每个元素为(x, y)坐标对
        interval (float, optional): 点击间隔时间（秒），默认使用配置值
        
    返回:
        bool: 所有点击操作是否都成功执行
        
    示例:
        # 依次点击三个按钮
        coords = [(100, 200), (300, 400), (500, 600)]
        perform_click_sequence(coords, 1.0)
    """
    if interval is None:
        interval = Config.CLICK_INTERVAL
    
    if not coordinates:
        logging.warning("点击坐标列表为空")
        return True
    
    logging.info(f"开始执行点击序列，共 {len(coordinates)} 个点击操作")
    
    success_count = 0
    for i, (x, y) in enumerate(coordinates, 1):
        logging.info(f"执行第 {i}/{len(coordinates)} 次点击")
        
        if tap_screen(x, y):
            success_count += 1
            if i < len(coordinates):  # 最后一次点击后不需要等待
                time.sleep(interval)
        else:
            logging.error(f"第 {i} 次点击失败: ({x}, {y})")
    
    success_rate = success_count / len(coordinates)
    logging.info(f"点击序列完成，成功率: {success_rate:.1%} ({success_count}/{len(coordinates)})")
    
    return success_count == len(coordinates)


def wait_and_retry(operation_func, max_retries: int = 3, 
                  retry_interval: float = 1.0, *args, **kwargs) -> bool:
    """
    带重试机制的操作执行函数
    
    对指定的操作函数进行重试执行，直到成功或达到最大重试次数。
    适用于网络不稳定或设备响应较慢的情况。
    
    参数:
        operation_func: 要执行的操作函数
        max_retries (int): 最大重试次数，默认3次
        retry_interval (float): 重试间隔时间（秒），默认1秒
        *args, **kwargs: 传递给操作函数的参数
        
    返回:
        bool: 操作是否最终成功执行
    """
    for attempt in range(max_retries + 1):
        try:
            result = operation_func(*args, **kwargs)
            if result:
                if attempt > 0:
                    logging.info(f"操作在第 {attempt + 1} 次尝试后成功")
                return True
        except Exception as e:
            logging.warning(f"第 {attempt + 1} 次尝试失败: {e}")
        
        if attempt < max_retries:
            logging.info(f"第 {attempt + 1} 次尝试失败，{retry_interval}秒后重试...")
            time.sleep(retry_interval)
    
    logging.error(f"操作在 {max_retries + 1} 次尝试后仍然失败")
    return False

# 优化2: 添加网络连接检查函数，增强错误处理 (2025-09-25)
def check_network_connection(host: str = "8.8.8.8", port: int = 53, timeout: int = 3) -> bool:
    """
    检查网络连接状态
    
    参数:
        host (str): 要连接的主机地址，默认为Google DNS
        port (int): 端口号，默认为53(DNS端口)
        timeout (int): 超时时间(秒)
        
    返回:
        bool: 网络是否连通
    """
    import socket
    try:
        socket.setdefaulttimeout(timeout)
        socket.socket(socket.AF_INET, socket.SOCK_STREAM).connect((host, port))
        return True
    except Exception:
        return False


# ==================== 主要业务逻辑 ====================
def execute_automation_sequence() -> bool:
    """
    执行自动化操作序列
    
    这是脚本的核心业务逻辑，定义了具体要执行的自动化操作步骤。
    可以根据实际需求修改这个函数中的操作序列。
    
    返回:
        bool: 整个操作序列是否成功完成
        
    操作步骤:
        1. 等待设备准备就绪
        2. 执行屏幕滑动操作
        3. 等待动画完成
        4. 执行一系列点击操作
    """
    try:
        # 步骤1: 等待设备准备就绪
        logging.info("等待设备准备就绪...")
        time.sleep(Config.DEVICE_READY_WAIT)
        
        # 步骤2: 执行滑动操作（从屏幕右侧向左滑动）
        logging.info("执行滑动操作...")
        start_coords = Config.SWIPE_COORDINATES['start']
        end_coords = Config.SWIPE_COORDINATES['end']
        
        if not swipe_screen(*start_coords, *end_coords):
            logging.error("滑动操作失败")
            return False
        
        # 步骤3: 等待动画完成
        logging.info("等待动画完成...")
        time.sleep(Config.ANIMATION_WAIT)
        
        # 步骤4: 执行点击序列
        logging.info("执行点击操作序列...")
        if not perform_click_sequence(Config.CLICK_COORDINATES):
            logging.error("点击序列执行失败")
            return False
        
        logging.info("自动化操作序列执行完成!")
        return True
        
    except KeyboardInterrupt:
        logging.info("操作被用户中断")
        return False
    except Exception as e:
        logging.error(f"执行自动化序列时发生错误: {e}")
        return False


def main() -> bool:
    """
    主函数 - 程序入口点
    
    负责初始化环境、检查设备连接状态，并执行自动化操作序列。
    包含完整的错误处理和状态检查逻辑。
    
    返回:
        bool: 主要操作是否成功完成
    """
    # 检查设备连接状态
    if not check_device_connected():
        logging.error("设备连接检查失败，程序退出")
        return False
    
    # 执行自动化操作序列
    return execute_automation_sequence()


# ==================== 程序入口 ====================
# 优化3: 使用argparse改进命令行参数处理 (2025-09-25)
def parse_arguments():
    """解析命令行参数"""
    parser = argparse.ArgumentParser(description="ADB自动化控制脚本")
    parser.add_argument("repeat_count", nargs="?", type=int, default=Config.DEFAULT_REPEAT_COUNT,
                        help="循环次数 (默认: %(default)s)")
    parser.add_argument("--interval", type=float, default=Config.OPERATION_INTERVAL,
                        help="操作间隔时间(秒) (默认: %(default)s)")
    parser.add_argument("--log-file", type=str, default=None,
                        help="日志文件路径 (默认: 输出到控制台)")
    parser.add_argument("--device-id", type=str, default=None,
                        help="指定设备ID (默认: 使用当前连接的设备)")
    return parser.parse_args()

# 优化4: 改进日志配置，支持文件输出 (2025-09-25)
def setup_logging_with_file(log_file: str = None):
    """
    配置日志系统，支持文件输出
    
    参数:
        log_file (str): 日志文件路径，如果为None则只输出到控制台
    """
    handlers = []
    
    # 控制台处理器
    console_handler = logging.StreamHandler()
    console_handler.setFormatter(logging.Formatter('%(asctime)s - %(levelname)s - %(message)s', 
                                                  datefmt='%Y-%m-%d %H:%M:%S'))
    handlers.append(console_handler)
    
    # 文件处理器
    if log_file:
        file_handler = logging.FileHandler(log_file, encoding='utf-8')
        file_handler.setFormatter(logging.Formatter('%(asctime)s - %(levelname)s - %(message)s', 
                                                   datefmt='%Y-%m-%d %H:%M:%S'))
        handlers.append(file_handler)
    
    logging.basicConfig(
        level=logging.INFO,
        handlers=handlers
    )

if __name__ == "__main__":
    # 解析命令行参数
    args = parse_arguments()
    
    # 初始化日志系统
    setup_logging_with_file(args.log_file)
    
    # 验证循环次数参数
    if args.repeat_count <= 0:
        logging.error("循环次数必须为正整数")
        sys.exit(1)
    
    # 显示执行计划
    logging.info(f"ADB自动化控制脚本启动")
    logging.info(f"计划执行 {args.repeat_count} 次操作循环")
    logging.info(f"操作间隔: {args.interval} 秒")
    if args.log_file:
        logging.info(f"日志文件: {args.log_file}")
    if args.device_id:
        logging.info(f"目标设备: {args.device_id}")
    
    # 执行主循环
    success_count = 0
    start_time = time.time()
    
    try:
        for i in range(args.repeat_count):
            logging.info(f"\n===== 执行第 {i+1}/{args.repeat_count} 次操作 =====")
            
            if main():
                success_count += 1
                logging.info(f"第 {i+1} 次操作成功完成")
            else:
                logging.error(f"第 {i+1} 次操作执行失败")
            
            # 计算并显示进度
            progress = (i + 1) / args.repeat_count * 100
            logging.info(f"总体进度: {progress:.1f}% ({i+1}/{args.repeat_count})")
            
            # 每次操作之间的间隔（最后一次循环后不需要等待）
            if i < args.repeat_count - 1:
                time.sleep(args.interval)
                
    except KeyboardInterrupt:
        logging.info("\n程序被用户中断!")
    except Exception as e:
        logging.error(f"\n程序执行过程中发生未知错误: {e}")
        raise
    
    # 显示执行统计
    end_time = time.time()
    total_time = end_time - start_time
    success_rate = success_count / args.repeat_count * 100 if args.repeat_count > 0 else 0
    
    logging.info("\n" + "=" * 50)
    logging.info("程序执行完毕 - 统计信息:")
    logging.info(f"总执行时间: {total_time:.2f} 秒")
    logging.info(f"计划执行次数: {args.repeat_count}")
    logging.info(f"成功执行次数: {success_count}")
    logging.info(f"成功率: {success_rate:.1f}%")
    logging.info(f"平均每次操作耗时: {total_time/args.repeat_count:.2f} 秒")
    logging.info("=" * 50)
    
    # 根据成功率设置退出代码
    exit_code = 0 if success_rate >= 90 else 1
    sys.exit(exit_code)