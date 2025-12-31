# 脚本名称：sys_check_oom_events.sh
# 用途：扫描内核日志中的 OOM Kill 事件，发现则告警
# 依赖：bash、dmesg；可选：journalctl
# 权限：建议 root（读取更完整日志）
# 参数：
#   --json               以 JSON 格式输出事件计数
# 环境变量：无
# 退出码：0 无事件；1 有事件；2 严重（大量/伴随 panic）；3 依赖缺失

set -u
. "$(dirname "$0")/../lib/common.sh"
load_env

JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
  esac; shift || true
done

require_cmd dmesg || exit_missing_dep dmesg

LOG=$(dmesg -T 2>/dev/null || dmesg)
COUNT=$(printf "%s" "$LOG" | grep -Ei 'Out of memory|Killed process' | wc -l)
PANIC=$(printf "%s" "$LOG" | grep -Ei 'Kernel panic' | wc -l)

SEV=0; [ "$COUNT" -gt 0 ] && SEV=1; [ "$PANIC" -gt 0 ] && SEV=2

if [ "$JSON" -eq 1 ]; then
  print_json kernel oom_events "$COUNT" 0 "$SEV"
else
  print_human kernel oom_events "$COUNT" 0 "$SEV"; echo "panic=$PANIC"
fi

if [ $SEV -ge 1 ]; then
  notify_email "OOM 事件" "oom=$COUNT panic=$PANIC host=$(hostname_short)" || true
fi
exit $SEV