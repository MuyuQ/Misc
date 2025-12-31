# 脚本名称：sys_check_swap_activity.sh
# 用途：检查 Swap 使用百分比，超阈值告警
# 依赖：bash、free、awk；可选：vmstat（换入换出速率）
# 权限：无需 root
# 参数：
#   --json               以 JSON 格式输出结果
#   --warn N             覆盖警告阈值（百分比）
#   --crit N             覆盖严重阈值（百分比）
# 环境变量：
#   SWAP_WARN_PERCENT=30 SWAP_CRIT_PERCENT=60
# 退出码：0 正常；1 警告；2 严重；3 依赖缺失

set -u
. "$(dirname "$0")/../lib/common.sh"
load_env

JSON=0; WARN=${SWAP_WARN_PERCENT:-30}; CRIT=${SWAP_CRIT_PERCENT:-60}
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
    --warn) WARN="$2"; shift ;;
    --crit) CRIT="$2"; shift ;;
  esac; shift || true
done

require_cmd free || exit_missing_dep free

read -r _ total used free <<< "$(free -m | awk '/Swap:/ {print $1,$2,$3,$4}')"
if [ "${total:-0}" -eq 0 ]; then
  USED_PCT=0
else
  USED_PCT=$(awk -v u="$used" -v t="$total" 'BEGIN{printf "%.2f", (u/t)*100}')
fi

SEV=0
awk "BEGIN{if($USED_PCT>=$CRIT)exit 2; else if($USED_PCT>=$WARN)exit 1; else exit 0;}" >/dev/null 2>&1
RC=$?; if [ $RC -eq 2 ]; then SEV=2; elif [ $RC -eq 1 ]; then SEV=1; else SEV=0; fi

if command -v vmstat >/dev/null 2>&1; then
  RATES=$(vmstat 1 2 | tail -1 | awk '{print "si="$7" so="$8}')
else
  RATES="si=NA so=NA"
fi

if [ "$JSON" -eq 1 ]; then
  print_json swap used_percent "$USED_PCT" "$WARN" "$SEV"
else
  print_human swap used_percent "$USED_PCT" "$WARN" "$SEV"; echo "$RATES"
fi

if [ $SEV -ge 1 ]; then
  notify_email "Swap 使用告警" "swap%=$USED_PCT $RATES warn=$WARN crit=$CRIT host=$(hostname_short)" || true
fi
exit $SEV