# 脚本名称：sys_check_disk_usage.sh
# 用途：检查各挂载点磁盘使用率与 inode 使用率，超阈值告警
# 依赖：bash、df、awk
# 权限：无需 root
# 参数：
#   --json               以 JSON 格式输出汇总（最大值）
#   --warn N             覆盖警告阈值（百分比）
#   --crit N             覆盖严重阈值（百分比）
# 环境变量：
#   DISK_WARN_PERCENT=80 DISK_CRIT_PERCENT=90
#   INODE_WARN_PERCENT=80 INODE_CRIT_PERCENT=90
# 退出码：0 正常；1 警告；2 严重；3 依赖缺失

set -u
. "$(dirname "$0")/../lib/common.sh"
load_env

JSON=0; WARN=${DISK_WARN_PERCENT:-80}; CRIT=${DISK_CRIT_PERCENT:-90}
IWARN=${INODE_WARN_PERCENT:-80}; ICRIT=${INODE_CRIT_PERCENT:-90}
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
    --warn) WARN="$2"; shift ;;
    --crit) CRIT="$2"; shift ;;
  esac; shift || true
done

require_cmd df || exit_missing_dep df

# 容量使用
MAX_PCT=0; MAX_MP=""
while read -r fs size used avail pct mp; do
  p=${pct%%%}
  if [ "$p" -gt "$MAX_PCT" ]; then MAX_PCT=$p; MAX_MP=$mp; fi
done < <(df -P | awk 'NR>1 {print $1,$2,$3,$4,$5,$6}')

# inode 使用
IMAX_PCT=0; IMAX_MP=""
if df -Pi >/dev/null 2>&1; then
  while read -r fs iused ifree ipct mp; do
    ip=${ipct%%%}
    if [ "$ip" -gt "$IMAX_PCT" ]; then IMAX_PCT=$ip; IMAX_MP=$mp; fi
  done < <(df -Pi | awk 'NR>1 {print $1,$3,$4,$5,$6}')
fi

SEV=0
if [ "$MAX_PCT" -ge "$CRIT" ] || [ "$IMAX_PCT" -ge "$ICRIT" ]; then SEV=2
elif [ "$MAX_PCT" -ge "$WARN" ] || [ "$IMAX_PCT" -ge "$IWARN" ]; then SEV=1
else SEV=0; fi

if [ "$JSON" -eq 1 ]; then
  print_json disk max_usage_percent "$MAX_PCT" "$WARN" "$SEV"
else
  print_human disk max_usage_percent "$MAX_PCT" "$WARN" "$SEV"
  echo "最大占用挂载点: $MAX_MP, inode最大占用: $IMAX_PCT@$IMAX_MP"
fi

if [ $SEV -ge 1 ]; then
  notify_email "磁盘使用告警" "disk%=$MAX_PCT mp=$MAX_MP inode%=$IMAX_PCT imp=$IMAX_MP warn=$WARN/$IWARN crit=$CRIT/$ICRIT host=$(hostname_short)" || true
fi
exit $SEV