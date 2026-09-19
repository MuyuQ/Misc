#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
图片边框处理工具

该脚本用于为图片添加边框，支持多种图片格式。
主要功能：
1. 批量处理目录中的图片
2. 为图片添加指定边框
3. 保持原图质量和格式

作者: Mcode
日期: 2025-09-25
"""

import os
import sys
import argparse  # 优化1: 添加argparse模块支持更好的命令行参数处理 (2025-09-25)
import concurrent.futures  # 优化2: 添加多线程支持以提高处理速度 (2025-09-25)
from PIL import Image
import logging

def ensure_dir(directory: str) -> None:
    """确保目录存在，如果不存在则创建。"""
    if not os.path.exists(directory):
        os.makedirs(directory, exist_ok=True)

def add_frame_to_image(image_path: str, frame_path: str, output_path: str) -> bool:
    """为图片添加边框。

    Args:
        image_path: 原始图片路径。
        frame_path: 边框图片路径（可为PSD/PNG）。
        output_path: 输出图片路径。

    Returns:
        处理是否成功。
    """
    try:
        # 打开原始图片
        img = Image.open(image_path)
        
        # 打开边框图片（PSD文件）
        try:
            frame = Image.open(frame_path)
        except Exception as e:
            logging.error(f"无法打开边框文件 {frame_path}: {e}")
            return False
        
        # 调整边框大小以匹配原始图片
        frame = frame.resize(img.size, Image.Resampling.LANCZOS)
        
        # 创建一个新的图片，与原始图片大小相同
        result = Image.new("RGBA", img.size, (0, 0, 0, 0))
        
        # 将原始图片粘贴到新图片上
        if img.mode != "RGBA":
            img = img.convert("RGBA")
        result.paste(img, (0, 0))
        
        # 将边框粘贴到新图片上
        result.paste(frame, (0, 0), frame)
        
        # 保存结果
        # 如果输出格式是JPG/JPEG，需要转换为RGB模式
        file_ext = os.path.splitext(output_path)[1].lower()
        if file_ext in [".jpg", ".jpeg"]:
            result = result.convert("RGB")
        
        # 确保输出文件的扩展名与原始文件相同
        result.save(output_path)
        return True
    except Exception as e:
        logging.error(f"处理图片 {image_path} 时出错: {e}")
        return False

def process_images(input_dir: str, output_dir: str, frame_path: str, max_workers: int = 4) -> tuple[int, int]:
    """处理目录中的所有图片。

    Args:
        input_dir: 输入图片目录。
        output_dir: 输出图片目录。
        frame_path: 边框图片路径。
        max_workers: 最大线程数。

    Returns:
        (总处理数, 成功数)。
    """
    # 确保输出目录存在
    ensure_dir(output_dir)
    
    # 支持的图片格式
    supported_formats = {".jpg", ".jpeg", ".png", ".bmp", ".gif"}
    
    # 收集所有需要处理的图片
    images_to_process = []
    for filename in os.listdir(input_dir):
        # 检查文件是否为支持的图片格式
        file_ext = os.path.splitext(filename)[1].lower()
        if file_ext in supported_formats:
            # 构建完整的文件路径
            input_path = os.path.join(input_dir, filename)
            output_path = os.path.join(output_dir, filename)
            # 跳过子目录
            if os.path.isfile(input_path):
                images_to_process.append((input_path, frame_path, output_path))
    
    # 优化3: 使用多线程并行处理图片 (2025-09-25)
    total = len(images_to_process)
    success = 0
    
    if total == 0:
        logging.warning("没有找到支持的图片文件。")
        return total, success
    
    logging.info(f"开始处理 {total} 张图片...")
    
    with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
        # 提交所有任务
        future_to_image = {executor.submit(add_frame_to_image, input_path, frame_path, output_path): 
                          (input_path, output_path) for input_path, frame_path, output_path in images_to_process}
        
        # 处理完成的任务
        for future in concurrent.futures.as_completed(future_to_image):
            input_path, output_path = future_to_image[future]
            try:
                result = future.result()
                if result:
                    success += 1
                    logging.info(f"已处理: {os.path.basename(input_path)} -> {os.path.basename(output_path)}")
                else:
                    logging.warning(f"处理失败: {os.path.basename(input_path)}")
            except Exception as e:
                logging.error(f"处理 {os.path.basename(input_path)} 时发生异常: {e}")
    
    return total, success

# 优化4: 使用argparse改进命令行参数处理 (2025-09-25)
def parse_arguments() -> argparse.Namespace:
    """解析命令行参数。"""
    parser = argparse.ArgumentParser(description="图片边框处理工具")
    parser.add_argument("-i", "--input", default="images",
                        help="输入图片目录 (默认: images)")
    parser.add_argument("-o", "--output", default="images_new",
                        help="输出图片目录 (默认: images_new)")
    parser.add_argument("-f", "--frame", default="kuangjia.psd",
                        help="边框图片路径 (默认: kuangjia.psd)")
    parser.add_argument("-w", "--workers", type=int, default=4,
                        help="最大线程数 (默认: 4)")
    return parser.parse_args()

# 优化5: 改进主函数，添加更详细的处理信息 (2025-09-25)
def main() -> int:
    args = parse_arguments()
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s %(levelname)s [%(threadName)s] %(message)s',
        datefmt='%H:%M:%S'
    )
    
    # 获取脚本所在目录
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    # 如果输入/输出路径是相对路径，则相对于脚本目录
    input_dir = os.path.join(script_dir, args.input) if not os.path.isabs(args.input) else args.input
    output_dir = os.path.join(script_dir, args.output) if not os.path.isabs(args.output) else args.output
    frame_path = os.path.join(script_dir, args.frame) if not os.path.isabs(args.frame) else args.frame
    
    # 检查输入目录是否存在
    if not os.path.exists(input_dir):
        logging.error(f"错误: 输入目录 '{input_dir}' 不存在!")
        return 1
    
    # 检查边框文件是否存在
    if not os.path.exists(frame_path):
        logging.error(f"错误: 边框文件 '{frame_path}' 不存在!")
        return 1
    
    # 显示处理信息
    logging.info(f"输入目录: {input_dir}")
    logging.info(f"输出目录: {output_dir}")
    logging.info(f"边框文件: {frame_path}")
    logging.info(f"线程数: {args.workers}")
    
    # 处理图片
    total, success = process_images(input_dir, output_dir, frame_path, args.workers)
    
    logging.info(f"\n处理完成! 共处理 {total} 张图片，成功 {success} 张。")
    if total > 0:
        success_rate = success / total * 100
        logging.info(f"成功率: {success_rate:.1f}%")
    
    return 0 if success == total else 1

if __name__ == "__main__":
    exit_code = main()
    sys.exit(exit_code)