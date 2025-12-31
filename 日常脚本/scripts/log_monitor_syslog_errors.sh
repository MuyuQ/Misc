# 脚本名称：log_monitor_syslog_errors.sh
# 用途：监控系统日志中的 ERROR/CRIT 级别消息速率并告警
# 依赖：bash、journalctl 或 /var/log/syslog
# 权限：建议 root（读取完整日志）
# 参数：
#   --json                 以 JSON 输出最近一小时错误条目数
# 环境变量：无
# 退出码：0 正常；1 警告（有错误）；2 严重（错误很多）；3 依赖缺失

set -u
. "$(dirname "$0")/../lib/common.sh"
load_env

JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
  esac; shift || true
done

COUNT=0
if command -v journalctl >/dev/null 2>&1; then
  COUNT=$(journalctl --since "-60 min" 2>/dev/null | grep -Ei '\b(ERROR|CRIT|FATAL)\b' | wc -l)
elif [ -r /var/log/syslog ]; then
  COUNT=$(grep -Ei '\b(ERROR|CRIT|FATAL)\b' /var/log/syslog 2>/dev/null | wc -l)
else
  exit_missing_dep journalctl/syslog
fi

SEV=0
if [ "$COUNT" -ge 100 ]; then SEV=2
elif [ "$COUNT" -gt 0 ]; then SEV=1
else SEV=0; fi

if [ "$JSON" -eq 1 ]; then
  print_json syslog errors_last_hour "$COUNT" 0 "$SEV"
else
  print_human syslog errors_last_hour "$COUNT" 0 "$SEV"
fi

if [ $SEV -ge 1 ]; then
  notify_email "系统日志错误" "count=$COUNT host=$(hostname_short)" || true
fi
exit $SEV