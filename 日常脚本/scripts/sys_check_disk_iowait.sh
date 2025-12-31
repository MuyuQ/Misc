# 脚本名称：sys_check_disk_iowait.sh
# 用途：检查 CPU I/O 等待比率，超阈值告警
# 依赖：bash、mpstat（sysstat）或 sar；无则降级为不可用
# 权限：无需 root
# 参数：
#   --json               以 JSON 格式输出结果
#   --warn N             覆盖警告阈值（百分比）
#   --crit N             覆盖严重阈值（百分比）
# 环境变量：
#   IOWAIT_WARN_PERCENT=20 IOWAIT_CRIT_PERCENT=40
# 退出码：0 正常；1 警告；2 严重；3 依赖缺失

set -u
. "$(dirname "$0")/../lib/common.sh"
load_env

JSON=0; WARN=${IOWAIT_WARN_PERCENT:-20}; CRIT=${IOWAIT_CRIT_PERCENT:-40}
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
    --warn) WARN="$2"; shift ;;
    --crit) CRIT="$2"; shift ;;
  esac; shift || true
done

IOWAIT=""
if command -v mpstat >/dev/null 2>&1; then
  IOWAIT=$(mpstat 1 1 | awk '/Average:/ {print $6}')
else
  exit_missing_dep mpstat
fi

SEV=0
awk "BEGIN{if($IOWAIT>=$CRIT)exit 2; else if($IOWAIT>=$WARN)exit 1; else exit 0;}" >/dev/null 2>&1
RC=$?; if [ $RC -eq 2 ]; then SEV=2; elif [ $RC -eq 1 ]; then SEV=1; else SEV=0; fi

if [ "$JSON" -eq 1 ]; then
  print_json cpu iowait_percent "$IOWAIT" "$WARN" "$SEV"
else
  print_human cpu iowait_percent "$IOWAIT" "$WARN" "$SEV"
fi

if [ $SEV -ge 1 ]; then
  notify_email "I/O 等待告警" "iowait%=$IOWAIT warn=$WARN crit=$CRIT host=$(hostname_short)" || true
fi
exit $SEV