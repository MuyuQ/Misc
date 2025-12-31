# 脚本名称：svc_check_cron_failures.sh
# 用途：检查最近的定时任务失败记录（CRON），发现异常时告警
# 依赖：bash、journalctl 或 syslog
# 权限：建议 root（读取完整日志）
# 参数：
#   --json                 以 JSON 输出失败事件数量
# 环境变量：无
# 退出码：0 无；1 有；2 严重（大量失败）；3 依赖缺失

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
  COUNT=$(journalctl -u cron --since "-60 min" 2>/dev/null | grep -Ei 'error|failed' | wc -l)
elif [ -r /var/log/syslog ]; then
  COUNT=$(grep -E 'CRON.*(error|failed)' /var/log/syslog 2>/dev/null | wc -l)
elif [ -r /var/log/cron ]; then
  COUNT=$(grep -Ei 'error|failed' /var/log/cron 2>/dev/null | wc -l)
else
  exit_missing_dep journalctl/syslog
fi

SEV=0
if [ "$COUNT" -ge 20 ]; then SEV=2
elif [ "$COUNT" -gt 0 ]; then SEV=1
else SEV=0; fi

if [ "$JSON" -eq 1 ]; then
  print_json cron failures "$COUNT" 0 "$SEV"
else
  print_human cron failures "$COUNT" 0 "$SEV"
fi

if [ $SEV -ge 1 ]; then
  notify_email "CRON 失败告警" "count=$COUNT host=$(hostname_short)" || true
fi
exit $SEV