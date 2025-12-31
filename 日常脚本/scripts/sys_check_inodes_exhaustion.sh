# 脚本名称：sys_check_inodes_exhaustion.sh
# 用途：检查各挂载点 inode 使用率，超阈值告警
# 依赖：bash、df
# 权限：无需 root
# 参数：
#   --json               以 JSON 格式输出汇总（最大值）
#   --warn N             覆盖警告阈值（百分比）
#   --crit N             覆盖严重阈值（百分比）
# 环境变量：
#   INODE_WARN_PERCENT=80 INODE_CRIT_PERCENT=90
# 退出码：0 正常；1 警告；2 严重；3 依赖缺失

set -u
. "$(dirname "$0")/../lib/common.sh"
load_env

JSON=0; WARN=${INODE_WARN_PERCENT:-80}; CRIT=${INODE_CRIT_PERCENT:-90}
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
    --warn) WARN="$2"; shift ;;
    --crit) CRIT="$2"; shift ;;
  esac; shift || true
done

require_cmd df || exit_missing_dep df

IMAX=0; IMP=""
while read -r fs iused ifree ipct mp; do
  p=${ipct%%%}
  if [ "$p" -gt "$IMAX" ]; then IMAX=$p; IMP=$mp; fi
done < <(df -Pi | awk 'NR>1 {print $1,$3,$4,$5,$6}')

SEV=0
if [ "$IMAX" -ge "$CRIT" ]; then SEV=2
elif [ "$IMAX" -ge "$WARN" ]; then SEV=1
else SEV=0; fi

if [ "$JSON" -eq 1 ]; then
  print_json inode max_usage_percent "$IMAX" "$WARN" "$SEV"
else
  print_human inode max_usage_percent "$IMAX" "$WARN" "$SEV"; echo "最大 inode 占用挂载点: $IMP"
fi

if [ $SEV -ge 1 ]; then
  notify_email "inode 使用告警" "inode%=$IMAX mp=$IMP warn=$WARN crit=$CRIT host=$(hostname_short)" || true
fi
exit $SEV