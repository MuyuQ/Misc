#!/bin/bash
# common.sh — 所有监控脚本的公共函数库
# 用法：在脚本中 source "$(dirname "$0")/../lib/common.sh"

set -u

# 加载默认配置（如存在）
load_env() {
  local env_file
  env_file="$(dirname "${BASH_SOURCE[0]}")/../config/default.env"
  if [ -r "$env_file" ]; then
    set -a
    # shellcheck source=/dev/null
    . "$env_file"
    set +a
  fi
}

# 返回短主机名
hostname_short() {
  hostname -s 2>/dev/null || hostname
}

# 检查命令是否存在（返回 0/1）
require_cmd() {
  command -v "$1" >/dev/null 2>&1
}

# 输出缺失依赖信息并以退出码 3 退出
exit_missing_dep() {
  echo "ERROR: 缺少依赖: $1" >&2
  exit 3
}

# 打印人类可读的一行摘要
# 用法: print_human <component> <metric> <value> <threshold> <severity>
print_human() {
  local comp="$1" metric="$2" val="$3" thresh="$4" sev="$5"
  local label
  case "$sev" in
    0) label="OK" ;;
    1) label="WARN" ;;
    2) label="CRIT" ;;
    *) label="UNKNOWN" ;;
  esac
  echo "[$label] $comp.$metric=$val (threshold=$thresh)"
}

# 打印 JSON 格式输出
# 用法: print_json <component> <metric> <value> <threshold> <severity>
print_json() {
  local comp="$1" metric="$2" val="$3" thresh="$4" sev="$5"
  printf '{"host":"%s","ts":"%s","component":"%s","metric":"%s","value":"%s","threshold":"%s","severity":%d}\n' \
    "$(hostname_short)" "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date)" \
    "$comp" "$metric" "$val" "$thresh" "$sev"
}

# 发送邮件告警（需要配置 SMTP_* 与 MAIL_TO）
# 用法: notify_email "主题" "正文"
notify_email() {
  local subject="$1" body="$2"
  [ -z "${MAIL_TO:-}" ] && return 0
  local script_dir
  script_dir="$(dirname "${BASH_SOURCE[0]}")"
  local mailer="$script_dir/../alerts/send_mail.py"
  if [ -x "$mailer" ]; then
    "$mailer" "$MAIL_TO" "$subject" "$body" 2>/dev/null
  elif command -v mail >/dev/null 2>&1; then
    echo "$body" | mail -s "$subject" "$MAIL_TO" 2>/dev/null
  else
    echo "WARN: 无法发送邮件（无 send_mail.py 或 mail 命令）" >&2
    return 1
  fi
}

# 打印帮助信息（由各脚本提供 DESCRIPTION / USAGE 变量）
print_help() {
  local desc="${DESCRIPTION:-未知脚本}"
  local usage="${USAGE:-}"
  local env_vars="${ENV_VARS:-}"
  echo "用法: $0 [OPTIONS]"
  echo ""
  echo "$desc"
  echo ""
  echo "选项:"
  echo "  --json      以 JSON 格式输出结果"
  echo "  --help, -h  显示此帮助信息"
  if [ -n "$usage" ]; then
    echo ""
    echo "$usage"
  fi
  if [ -n "$env_vars" ]; then
    echo ""
    echo "环境变量:"
    echo "$env_vars"
  fi
  echo ""
  echo "退出码: 0=正常 1=警告 2=严重 3=依赖缺失"
}
