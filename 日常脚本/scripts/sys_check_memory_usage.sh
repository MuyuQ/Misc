# 脚本名称：sys_check_memory_usage.sh
# 用途：检查内存占用百分比，超阈值时告警并输出 JSON 可选
# 依赖：bash、free、awk
# 权限：无需 root
# 参数：
#   --json               以 JSON 格式输出结果
#   --warn N             覆盖警告阈值（百分比）
#   --crit N             覆盖严重阈值（百分比）
# 环境变量：
#   MEM_WARN_PERCENT=80 MEM_CRIT_PERCENT=90
# 退出码：0 正常；1 警告；2 严重；3 依赖缺失

set -u
. "$(dirname "$0")/../lib/common.sh"
load_env

JSON=0; WARN=${MEM_WARN_PERCENT:-80}; CRIT=${MEM_CRIT_PERCENT:-90}
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
    --warn) WARN="$2"; shift ;;
    --crit) CRIT="$2"; shift ;;
  esac; shift || true
done

require_cmd free || exit_missing_dep free

USED_PCT=$(free -m | awk '/Mem:/ {printf "%.2f", ($3/$2)*100}')

SEV=0
awk "BEGIN{if($USED_PCT>=$CRIT)exit 2; else if($USED_PCT>=$WARN)exit 1; else exit 0;}" >/dev/null 2>&1
RC=$?; if [ $RC -eq 2 ]; then SEV=2; elif [ $RC -eq 1 ]; then SEV=1; else SEV=0; fi

if [ "$JSON" -eq 1 ]; then
  print_json memory used_percent "$USED_PCT" "$WARN" "$SEV"
else
  print_human memory used_percent "$USED_PCT" "$WARN" "$SEV"
fi

if [ $SEV -ge 1 ]; then
  notify_email "内存占用告警" "mem%=$USED_PCT warn=$WARN crit=$CRIT host=$(hostname_short)" || true
fi
exit $SEV