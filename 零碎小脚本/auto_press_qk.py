#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
自动按键脚本 - 自动交替按下 'q' 和 'k' 键

该脚本使用 pyautogui 库模拟键盘输入，自动交替按下 'q' 和 'k' 键，
每次按键后会随机等待 2000-5000 毫秒。主要用于需要重复按键的场景，
如游戏自动化、按键测试等。

依赖库:
    - pyautogui: 用于模拟键盘输入
    - time: 用于控制等待时间
    - random: 用于生成随机等待时间
    - argparse: 用于处理命令行参数

使用方法:
    1. 确保已安装所需依赖: pip install pyautogui
    2. 运行脚本: python auto_press_qk.py
    3. 按 Ctrl+C 停止脚本

作者: Mcode
版本: 1.2
更新日期: 2025-09-25
"""

import pyautogui  # 用于模拟键盘输入
import time       # 用于控制等待时间
import random     # 用于生成随机数
import argparse   # 用于处理命令行参数 (2025-09-25)
import sys        # 用于处理命令行参数 (2025-09-25)
import logging

# 定义常量
MIN_WAIT_MS = 2000  # 最小等待时间（毫秒）
MAX_WAIT_MS = 5000  # 最大等待时间（毫秒）

# 优化1: 添加按键配置 (2025-09-25)
DEFAULT_KEYS = ['q', 'k']  # 默认按键序列
DEFAULT_MAX_CYCLES = 0       # 默认最大循环次数，0表示无限循环

# 优化2: 添加参数解析函数 (2025-09-25)
def parse_arguments() -> argparse.Namespace:
    """解析命令行参数。"""
    parser = argparse.ArgumentParser(description="自动按键脚本")
    parser.add_argument("--keys", nargs="+", default=DEFAULT_KEYS,
                        help=f"按键序列 (默认: {' '.join(DEFAULT_KEYS)})")
    parser.add_argument("--min-wait", type=int, default=MIN_WAIT_MS,
                        help=f"最小等待时间(毫秒) (默认: {MIN_WAIT_MS})")
    parser.add_argument("--max-wait", type=int, default=MAX_WAIT_MS,
                        help=f"最大等待时间(毫秒) (默认: {MAX_WAIT_MS})")
    parser.add_argument("--max-cycles", type=int, default=DEFAULT_MAX_CYCLES,
                        help=f"最大循环次数，0表示无限循环 (默认: {DEFAULT_MAX_CYCLES})")
    parser.add_argument("--stats-interval", type=int, default=10,
                        help="统计信息显示间隔(循环次数) (默认: 10)")
    return parser.parse_args()

# 优化3: 创建主执行函数，提高代码模块化 (2025-09-25)
def run_auto_press(keys: list[str], min_wait_ms: int, max_wait_ms: int, max_cycles: int, stats_interval: int) -> bool:
    """执行自动按键操作。

    Args:
        keys: 按键序列。
        min_wait_ms: 最小等待时间(毫秒)。
        max_wait_ms: 最大等待时间(毫秒)。
        max_cycles: 最大循环次数，0表示无限循环。
        stats_interval: 统计信息显示间隔。
    """
    # 显示启动信息
    logging.info("="*50)
    logging.info("自动按键脚本已启动")
    logging.info(f"将按顺序按下键: {' '.join(keys)}")
    logging.info(f"每次按键后随机等待 {min_wait_ms}-{max_wait_ms} 毫秒")
    if max_cycles > 0:
        logging.info(f"最大执行次数: {max_cycles} 次")
    else:
        logging.info("按 Ctrl+C 停止程序")
    logging.info("="*50)
    
    counter = 0  # 按键计数器
    start_time = time.time()  # 记录开始时间
    
    try:
        while True:
            counter += 1  # 增加计数器
            
            # 如果设置了最大循环次数且已达到，停止执行
            if 0 < max_cycles < counter:
                break
            
            # 依次按下所有按键
            for key in keys:
                pyautogui.press(key)
                logging.info(f"[{counter}] 已按下 '{key}' 键")
                
                # 随机等待
                wait_time_ms = random.randint(min_wait_ms, max_wait_ms)
                logging.info(f"等待 {wait_time_ms} 毫秒...")
                time.sleep(wait_time_ms / 1000)  # 将毫秒转换为秒
            
            # 每隔一定循环次数显示一次统计信息
            if counter % stats_interval == 0:
                elapsed_time = time.time() - start_time
                avg_time_per_cycle = elapsed_time / counter
                logging.info(f"\n已完成 {counter} 次按键循环，总运行时间: {elapsed_time:.2f} 秒")
                logging.info(f"平均每次循环用时: {avg_time_per_cycle:.2f} 秒\n")
                
                # 显示每秒按键次数
                keys_per_second = (counter * len(keys)) / elapsed_time if elapsed_time > 0 else 0
                logging.info(f"平均按键速度: {keys_per_second:.2f} 键/秒\n")

    except KeyboardInterrupt:
        # 处理用户按下 Ctrl+C 的情况
        elapsed_time = time.time() - start_time
        logging.info("\n程序被用户中断!")
        logging.info(f"总共执行了 {counter} 次按键循环，总运行时间: {elapsed_time:.2f} 秒")
        
    except Exception as e:
        # 处理其他可能的异常
        logging.error(f"\n程序执行过程中发生错误: {e}")
        return False
    
    finally:
        # 显示最终统计信息
        elapsed_time = time.time() - start_time
        logging.info(f"\n最终统计信息:")
        logging.info(f"执行了 {counter} 次按键循环")
        logging.info(f"总运行时间: {elapsed_time:.2f} 秒")
        if elapsed_time > 0:
            avg_time_per_cycle = elapsed_time / counter if counter > 0 else 0
            keys_per_second = (counter * len(keys)) / elapsed_time if elapsed_time > 0 else 0
            logging.info(f"平均每次循环用时: {avg_time_per_cycle:.2f} 秒")
            logging.info(f"平均按键速度: {keys_per_second:.2f} 键/秒")
        logging.info("程序已退出。")
    
    return True

def main() -> int:
    """主函数。"""
    args = parse_arguments()
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s %(levelname)s [%(threadName)s] %(message)s',
        datefmt='%H:%M:%S'
    )
    
    # 验证参数
    if args.min_wait >= args.max_wait:
        logging.error("错误: 最小等待时间必须小于最大等待时间")
        return 1
    
    if args.max_cycles < 0:
        logging.error("错误: 最大循环次数不能为负数")
        return 1
    
    if args.stats_interval <= 0:
        logging.error("错误: 统计信息显示间隔必须为正数")
        return 1
    
    # 执行自动按键
    ok = run_auto_press(args.keys, args.min_wait, args.max_wait, args.max_cycles, args.stats_interval)
    return 0 if ok else 1

if __name__ == "__main__":
    exit_code = main()
    sys.exit(exit_code)