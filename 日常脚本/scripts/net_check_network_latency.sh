# 脚本名称：net_check_network_latency.sh
# 用途：对多个目标执行 ping，统计丢包率与延迟，超阈值告警
# 依赖：bash、ping、awk
# 权限：无需 root
# 参数：
#   --json               以 JSON 格式输出最差目标的结果
#   --targets a,b,c      覆盖目标列表（逗号分隔）
#   --loss-warn N        覆盖丢包警告阈值（百分比）
#   --loss-crit N        覆盖丢包严重阈值（百分比）
# 环境变量：
#   PING_TARGETS="1.1.1.1,8.8.8.8" PING_LOSS_WARN_PERCENT=20 PING_LOSS_CRIT_PERCENT=50
# 退出码：0 正常；1 警告；2 严重；3 依赖缺失

set -u
. "$(dirname "$0")/../lib/common.sh"
load_env

require_cmd ping || exit_missing_dep ping

JSON=0; TARGETS=${PING_TARGETS:-1.1.1.1}; LWARN=${PING_LOSS_WARN_PERCENT:-20}; LCRIT=${PING_LOSS_CRIT_PERCENT:-50}
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
    --targets) TARGETS="$2"; shift ;;
    --loss-warn) LWARN="$2"; shift ;;
    --loss-crit) LCRIT="$2"; shift ;;
  esac; shift || true
done

WORST_LOSS=0; WORST_HOST=""; WORST_LAT="NA"
IFS=',' read -r -a arr <<< "$TARGETS"
for h in "${arr[@]}"; do
  out=$(ping -c 3 -w 5 "$h" 2>/dev/null)
  loss=$(echo "$out" | awk -F, '/packets transmitted/ {print $3}' | awk -F '%' '{print $1}' | tr -d ' ')
  lat=$(echo "$out" | awk -F '=' '/rtt min/ {print $2}' | awk -F '/' '{print $2}' )
  [ -z "$loss" ] && loss=100
  if [ "$loss" -gt "$WORST_LOSS" ]; then WORST_LOSS=$loss; WORST_HOST=$h; WORST_LAT=${lat:-NA}; fi
done

SEV=0
if [ "$WORST_LOSS" -ge "$LCRIT" ]; then SEV=2
elif [ "$WORST_LOSS" -ge "$LWARN" ]; then SEV=1
else SEV=0; fi

if [ "$JSON" -eq 1 ]; then
  print_json network ping_loss_percent "$WORST_LOSS" "$LWARN" "$SEV"
else
  print_human network ping_loss_percent "$WORST_LOSS" "$LWARN" "$SEV"; echo "host=$WORST_HOST avg_latency_ms=$WORST_LAT"
fi

if [ $SEV -ge 1 ]; then
  notify_email "网络丢包告警" "loss%=$WORST_LOSS host=$WORST_HOST lat=$WORST_LAT warn=$LWARN crit=$LCRIT" || true
fi
exit $SEV