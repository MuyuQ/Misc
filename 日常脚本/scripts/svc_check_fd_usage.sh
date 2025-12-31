# 脚本名称：svc_check_fd_usage.sh
# 用途：检查系统文件句柄使用率（/proc/sys/fs/file-nr），超阈值告警
# 依赖：bash、/proc/sys/fs/file-nr
# 权限：无需 root
# 参数：
#   --json                 以 JSON 输出使用率（百分比）
#   --warn N               覆盖警告阈值（百分比）
#   --crit N               覆盖严重阈值（百分比）
# 环境变量：
#   FD_WARN_PERCENT=70 FD_CRIT_PERCENT=90
# 退出码：0 正常；1 警告；2 严重；3 依赖缺失

set -u
. "$(dirname "$0")/../lib/common.sh"
load_env

JSON=0; WARN=${FD_WARN_PERCENT:-70}; CRIT=${FD_CRIT_PERCENT:-90}
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
    --warn) WARN="$2"; shift ;;
    --crit) CRIT="$2"; shift ;;
  esac; shift || true
done

FILE=/proc/sys/fs/file-nr
[ -r "$FILE" ] || exit_missing_dep file-nr
read -r alloc unused max < "$FILE"
USED=$((alloc - unused))
PCT=$(awk -v u="$USED" -v m="$max" 'BEGIN{if(m==0)print 0; else printf "%.2f", (u*100.0)/m}')

SEV=0
awk "BEGIN{if($PCT>=$CRIT)exit 2; else if($PCT>=$WARN)exit 1; else exit 0;}" >/dev/null 2>&1
RC=$?; if [ $RC -eq 2 ]; then SEV=2; elif [ $RC -eq 1 ]; then SEV=1; else SEV=0; fi

if [ "$JSON" -eq 1 ]; then
  print_json fd used_percent "$PCT" "$WARN" "$SEV"
else
  print_human fd used_percent "$PCT" "$WARN" "$SEV"; echo "used=$USED max=$max"
fi

if [ $SEV -ge 1 ]; then
  notify_email "文件句柄占用告警" "fd%=$PCT used=$USED max=$max host=$(hostname_short)" || true
fi
exit $SEV