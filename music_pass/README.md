# 自动点击"领取成功"按钮脚本

## 项目描述

该脚本通过Appium远程控制Android设备并自动点击"领取成功"按钮。支持通过Wi-Fi无线连接到真实Android设备，无需USB直连。

主要特性：

1. **无线连接支持**：通过Wi-Fi连接到Android设备，无需USB线缆连接
2. **多种定位策略**：支持通过文本、ID、XPath等多种方式定位并点击"领取成功"按钮
3. **灵活配置**：支持自定义检测间隔、超时时间等参数，默认每2秒检测一次

## 环境要求

### 系统和软件要求

- Python 3.8+
- Appium Server（需要支持远程ADB连接）
- Android设备（已开启开发者选项和USB调试）

### 安装依赖

```bash
pip install Appium-Python-Client
```

### 启动Appium服务

启动Appium Server时需要允许ADB Shell访问：

```bash
appium --allow-insecure=adb_shell
```

## 使用方法

### 获取应用信息

首先需要获取目标应用的包名和Activity名：

```bash
adb shell dumpsys window | grep mCurrentFocus
```

输出示例：`mCurrentFocus=Window{...com.example.app/com.example.app.MainActivity}`

### 基本用法

```bash
python main.py --device-ip <设备IP> --app-package <应用包名> --app-activity <应用Activity名>
```

### 参数说明

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `--device-ip` | Android设备的IP地址 | 必需参数 |
| `--device-port` | Android设备的adb端口 | 5555 |
| `--appium-ip` | Appium服务器的IP地址 | 127.0.0.1 |
| `--appium-port` | Appium服务器的端口 | 4723 |
| `--app-package` | 目标应用的包名 | 必需参数 |
| `--app-activity` | 目标应用的Activity名 | 必需参数 |
| `--button-text` | 要点击的按钮文本 | 领取成功 |
| `--button-id` | 要点击的按钮ID | 无 |
| `--button-xpath` | 要点击的按钮XPath | 无 |
| `--interval` | 检测间隔（秒） | 2 |
| `--timeout` | 检测超时时间（秒），设为0表示不超时 | 300 |
| `--screenshot` | 启用截图功能 | 关闭 |
| `--screenshot-dir` | 截图保存目录 | screenshots |
| `--config` | 配置文件路径（支持JSON和YAML格式） | 无 |
| `--debug` | 启用调试模式，输出详细日志 | 关闭 |

### 使用示例

```bash
python main.py --device-ip 192.168.1.100 --app-package com.example.app --app-activity com.example.app.MainActivity --button-text "领取成功" --interval 1 --timeout 600
```

## 常见问题

### 连接问题

- **无法连接到设备**：确保设备已连接到同一Wi-Fi网络，并且adb端口（默认5555）已开启
- **Appium连接失败**：确保Appium Server正在运行，并且端口4723可访问

### 元素定位问题

- **找不到按钮元素**：如果文本定位失败，可以尝试使用更精确的定位方式：
  1. 使用Appium Inspector查看元素属性
  2. 通过resource-id或XPath进行精确定位

### 网络和连接

- 确保Android设备和运行脚本的电脑在同一网络下
- 如需断开连接，可使用ADB命令：`adb disconnect <设备IP>:5555`

## 高级用法

### 自定义元素定位策略

如果默认的文本定位不准确，可以通过修改`find_and_click_button`函数来实现更精确的定位：

```python
# 通过resource-id定位
elements = driver.find_elements(AppiumBy.ID, "button_id")

# 通过XPath定位
elements = driver.find_elements(AppiumBy.XPATH, "//android.widget.Button[@text='领取成功']")
```

### 配置文件支持

可以使用配置文件来管理参数，支持JSON和YAML两种格式。

#### YAML配置文件（推荐）

创建`config.yml`文件：

```yaml
# 设备连接配置
device_ip: "192.168.1.100"
device_port: "5555"

# Appium服务器配置
appium_ip: "127.0.0.1"
appium_port: "4723"

# 应用配置
app_package: "com.example.app"
app_activity: "com.example.app.MainActivity"

# 按钮定位配置
button_text: "领取成功"
button_id: "com.example.app:id/btn_success"
button_xpath: "//android.widget.Button[@text='领取成功']"

# 运行参数
interval: 2
timeout: 300

# 截图配置
screenshot: true
screenshot_dir: "screenshots"

# 调试配置
debug: false
```

#### JSON配置文件（兼容）

创建`config.json`文件：

```json
{
    "device_ip": "192.168.1.100",
    "app_package": "com.example.app",
    "app_activity": "com.example.app.MainActivity",
    "button_text": "领取成功",
    "interval": 2,
    "timeout": 300,
    "debug": false,
    "screenshot": true,
    "screenshot_dir": "screenshots"
}
```

然后使用：

```bash
python main.py --config config.yml
# 或
python main.py --config config.json
```

## 注意事项

1. 使用前请确保已获得设备使用权限
2. 建议在测试环境中先验证脚本功能
3. 长时间运行时注意设备电量和网络稳定性
4. 遵守相关应用的使用条款和法律法规