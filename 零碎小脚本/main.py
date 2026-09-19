#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
图片下载与转换工具

该脚本从Excel文件中读取商品信息和图片链接，下载图片并保存为JPG或PNG格式。
主要功能：
1. 读取Excel文件中的商品信息
2. 下载指定URL的图片
3. 处理RGBA图像（转换为RGB模式）
4. 保存图片到本地文件系统

作者：Mcode
日期：2025-09-25
版本：1.1
"""

import pandas as pd
import requests
from PIL import Image
from io import BytesIO
import os
import re
import sys
import argparse  # 优化1: 添加argparse模块支持更好的命令行参数处理 (2025-09-25)
import concurrent.futures  # 优化2: 添加多线程支持以提高下载速度 (2025-09-25)
import time  # 优化3: 添加时间处理用于下载进度显示 (2025-09-25)
import logging


def clean_filename(filename: str) -> str:
    """清理文件名中的非法字符并限制长度。

    Args:
        filename: 原始文件名。

    Returns:
        清理后的安全文件名。
    """
    # 移除Windows文件系统不允许的字符: \ / : * ? " < > |
    cleaned = re.sub(r'[\\/:*?"<>|]', "_", filename)
    # 限制文件名长度，防止路径过长
    if len(cleaned) > 100:
        cleaned = cleaned[:100]
    return cleaned


def download_and_convert_image(
    url: str,
    filename: str,
    output_dir: str = "images",
    timeout: int = 30,
    retries: int = 3,
) -> bool:
    """下载并保存图片（必要时进行模式转换）。

    Args:
        url: 图片的URL地址。
        filename: 保存的文件名（不含扩展名）。
        output_dir: 输出目录。
        timeout: 下载超时时间（秒）。
        retries: 失败后的重试次数。

    Returns:
        是否成功下载并保存。
    """
    # 清理文件名
    safe_filename = clean_filename(filename)
    image = None

    # 优化4: 添加重试机制 (2025-09-25)
    for attempt in range(retries + 1):
        try:
            # 下载图片
            response = requests.get(url, timeout=timeout)
            response.raise_for_status()  # 检查请求是否成功
            image = Image.open(BytesIO(response.content))

            # 确保图片目录存在
            if not os.path.exists(output_dir):
                os.makedirs(output_dir, exist_ok=True)

            # 检查图像模式，如果是RGBA，转换为RGB
            if image.mode == "RGBA":
                # 创建白色背景
                background = Image.new("RGB", image.size, (255, 255, 255))
                # 将RGBA图像合成到白色背景上
                background.paste(image, mask=image.split()[3])  # 使用alpha通道作为蒙版
                image = background

            # 保存图片为JPG格式（跨平台路径）
            save_path = os.path.join(output_dir, f"{safe_filename}-1.jpg")
            image.save(save_path, "JPEG")
            return True

        except requests.exceptions.RequestException as req_err:
            if attempt < retries:
                logging.warning(
                    f"下载图片失败 {url} (尝试 {attempt + 1}/{retries}): {req_err}"
                )
                time.sleep(2**attempt)  # 指数退避
            else:
                logging.error(f"下载图片失败 {url}: {req_err}")
        except Exception as e:
            if attempt < retries:
                logging.warning(
                    f"处理图片失败 {url} (尝试 {attempt + 1}/{retries}): {e}"
                )
                time.sleep(2**attempt)  # 指数退避
            else:
                logging.error(f"处理图片失败 {url}: {e}")
                if image:
                    try:
                        # 尝试保存为PNG格式（跨平台路径）
                        save_path = os.path.join(
                            output_dir, f"{safe_filename}-1.png")
                        image.save(save_path, "PNG")
                        return True
                    except Exception as e2:
                        logging.error(f"保存为PNG格式失败: {e2}")

    return False


# 优化5: 使用argparse改进命令行参数处理 (2025-09-25)
def parse_arguments() -> argparse.Namespace:
    """解析命令行参数。"""
    parser = argparse.ArgumentParser(description="图片下载与转换工具")
    parser.add_argument(
        "-f", "--file", default="ddddd.xlsx", help="Excel文件路径 (默认: ddddd.xlsx)"
    )
    parser.add_argument(
        "-s", "--sheet", default="商品详情", help="工作表名称 (默认: 商品详情)"
    )
    parser.add_argument(
        "-o", "--output", default="images", help="图片输出目录 (默认: images)"
    )
    parser.add_argument(
        "-c", "--column-url", default="图片链接", help="图片URL列名 (默认: 图片链接)"
    )
    parser.add_argument(
        "-n", "--column-name", default="spu", help="文件名列名 (默认: spu)"
    )
    parser.add_argument(
        "-w", "--workers", type=int, default=5, help="下载线程数 (默认: 5)"
    )
    parser.add_argument(
        "-t", "--timeout", type=int, default=30, help="下载超时时间(秒) (默认: 30)"
    )
    parser.add_argument(
        "-r", "--retries", type=int, default=3, help="下载重试次数 (默认: 3)"
    )
    return parser.parse_args()


# 优化6: 添加多线程下载支持 (2025-09-25)
def download_images_concurrent(
    df: pd.DataFrame,
    url_column: str,
    name_column: str,
    output_dir: str,
    workers: int,
    timeout: int,
    retries: int,
) -> tuple[int, int]:
    """并发下载图片。

    Args:
        df: Excel读取的DataFrame。
        url_column: 图片URL列名。
        name_column: 文件名列名。
        output_dir: 输出目录。
        workers: 线程数。
        timeout: 下载超时时间。
        retries: 下载重试次数。

    Returns:
        (总记录数, 成功数量)。
    """
    total_rows = len(df)
    success_count = 0
    completed_count = 0

    logging.info(f"开始下载 {total_rows} 张图片...")
    start_time = time.time()

    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as executor:
        # 提交所有下载任务
        future_to_index = {}
        for index, row in df.iterrows():
            # 跳过缺失值或空URL/文件名
            img_url = row.get(url_column)
            new_filename = row.get(name_column)
            if pd.isna(img_url) or pd.isna(new_filename):
                continue
            future = executor.submit(
                download_and_convert_image,
                str(img_url),
                str(new_filename),
                output_dir,
                timeout,
                retries,
            )
            future_to_index[future] = index

        # 处理完成的任务
        for future in concurrent.futures.as_completed(future_to_index):
            index = future_to_index[future]
            try:
                result = future.result()
                if result:
                    success_count += 1
                    logging.info(f"处理第 {index+1}/{total_rows} 条记录: 成功")
                else:
                    logging.warning(f"处理第 {index+1}/{total_rows} 条记录: 失败")
            except Exception as e:
                logging.error(f"处理第 {index+1}/{total_rows} 条记录时发生异常: {e}")

            # 显示进度
            completed_count += 1
            progress = completed_count / total_rows * 100
            logging.info(
                f"进度: {progress:.1f}% ({completed_count}/{total_rows})")

    end_time = time.time()
    elapsed_time = end_time - start_time

    logging.info(f"\n下载完成! 总用时: {elapsed_time:.2f} 秒")
    logging.info(f"平均速度: {total_rows/elapsed_time:.2f} 张/秒")

    return total_rows, success_count


# 优化7: 改进主函数 (2025-09-25)
def main() -> int:
    """主函数：读取Excel文件并处理所有图片。"""
    args = parse_arguments()
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s [%(threadName)s] %(message)s",
        datefmt="%H:%M:%S",
    )

    try:
        logging.info(f"正在读取Excel文件: {args.file}, 工作表: {args.sheet}")
        df = pd.read_excel(args.file, sheet_name=args.sheet)

        # 校验必要列是否存在
        missing_cols = []
        for col in [args.column_url, args.column_name]:
            if col not in df.columns:
                missing_cols.append(col)
        if missing_cols:
            logging.error(f"错误: Excel缺少必要列: {', '.join(missing_cols)}")
            return 1

        # 显示处理信息
        total_rows = len(df)
        logging.info(f"共找到 {total_rows} 条记录需要处理")

        # 并发下载图片
        total, success = download_images_concurrent(
            df,
            args.column_url,
            args.column_name,
            args.output,
            args.workers,
            args.timeout,
            args.retries,
        )

        logging.info(f"\n所有图片处理完成！成功: {success}/{total}")
        if total > 0:
            success_rate = success / total * 100
            logging.info(f"成功率: {success_rate:.1f}%")

        return 0 if success == total else 1

    except FileNotFoundError:
        logging.error(f"错误: 找不到Excel文件 {args.file}")
        return 1
    except Exception as e:
        logging.error(f"处理Excel文件时出错: {e}")
        return 1


if __name__ == "__main__":
    exit_code = main()
    sys.exit(exit_code)
