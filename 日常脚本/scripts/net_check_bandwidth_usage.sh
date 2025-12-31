# 脚本名称：net_check_bandwidth_usage.sh
# 用途：按网卡计算瞬时带宽（bytes/s），报告最大值并可阈值告警
# 依赖：bash、/sys/class/net/*/statistics
# 权限：无需 root
# 参数：
#   --json                 以 JSON 输出最大 RX/TX 速率（bytes/s）
#   --warn N               覆盖警告阈值（bytes/s）
#   --crit N               覆盖严重阈值（bytes/s）
# 环境变量：
#   BANDWIDTH_WARN_BPS=12500000（约100Mbps） BPS_CRIT=62500000（约500Mbps）
# 退出码：0 正常；1 警告；2 严重；3 依赖缺失

set -u
. "$(dirname "$0")/../lib/common.sh"
load_env

JSON=0; WARN=${BANDWIDTH_WARN_BPS:-12500000}; CRIT=${BPS_CRIT:-62500000}
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
    --warn) WARN="$2"; shift ;;
    --crit) CRIT="$2"; shift ;;
  esac; shift || true
done

NIC_DIR=/sys/class/net
[ -d "$NIC_DIR" ] || exit_missing_dep sysfs_net

declare -A rx1 tx1 rx2 tx2
for n in $(ls "$NIC_DIR"); do
  [ -f "$NIC_DIR/$n/statistics/rx_bytes" ] || continue
  rx1[$n]=$(cat "$NIC_DIR/$n/statistics/rx_bytes")
  tx1[$n]=$(cat "$NIC_DIR/$n/statistics/tx_bytes")
done
sleep 1
for n in "${!rx1[@]}"; do
  rx2[$n]=$(cat "$NIC_DIR/$n/statistics/rx_bytes")
  tx2[$n]=$(cat "$NIC_DIR/$n/statistics/tx_bytes")
done

MAX=0; IFACE=""; DIR="rx"
for n in "${!rx1[@]}"; do
  r=$(( ${rx2[$n]} - ${rx1[$n]} ))
  t=$(( ${tx2[$n]} - ${tx1[$n]} ))
  if [ "$r" -gt "$MAX" ]; then MAX=$r; IFACE=$n; DIR="rx"; fi
  if [ "$t" -gt "$MAX" ]; then MAX=$t; IFACE=$n; DIR="tx"; fi
done

SEV=0
if [ "$MAX" -ge "$CRIT" ]; then SEV=2
elif [ "$MAX" -ge "$WARN" ]; then SEV=1
else SEV=0; fi

if [ "$JSON" -eq 1 ]; then
  print_json network max_bps "$MAX" "$WARN" "$SEV"
else
  print_human network max_bps "$MAX" "$WARN" "$SEV"; echo "iface=$IFACE dir=$DIR"
fi

if [ $SEV -ge 1 ]; then
  notify_email "带宽使用告警" "max_bps=$MAX iface=$IFACE dir=$DIR warn=$WARN crit=$CRIT" || true
fi
exit $SEV