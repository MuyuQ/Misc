# 脚本名称：stg_check_backup_status.sh
# 用途：检查最近备份完成标记/日志时间，过期则告警
# 依赖：bash、stat、date
# 权限：无需 root（取决于标记文件权限）
# 参数：
#   --json                   以 JSON 输出最老标记的年龄（小时）
#   --markers p1,p2          覆盖备份标记文件路径列表
#   --max-age H              覆盖最大允许年龄（小时）
# 环境变量：
#   BACKUP_MARKERS="/var/log/backup.ok" BACKUP_MAX_AGE_HOURS=24
# 退出码：0 正常；1 过期；2 严重（长期未备份）；3 依赖缺失

set -u
. "$(dirname "$0")/../lib/common.sh"
load_env

JSON=0; MARKERS=${BACKUP_MARKERS:-/var/log/backup.ok}; MAXH=${BACKUP_MAX_AGE_HOURS:-24}
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
    --markers) MARKERS="$2"; shift ;;
    --max-age) MAXH="$2"; shift ;;
  esac; shift || true
done

OLDEST=0; DETAIL=""; FOUND=0
IFS=',' read -r -a arr <<< "$MARKERS"
now=$(date +%s)
for p in "${arr[@]}"; do
  [ -r "$p" ] || continue
  FOUND=$((FOUND+1))
  mt=$(stat -c %Y "$p" 2>/dev/null || echo 0)
  age=$(( (now-mt)/3600 ))
  [ "$age" -gt "$OLDEST" ] && OLDEST=$age
  DETAIL="$DETAIL $p:${age}h"
done

SEV=0
if [ "$FOUND" -eq 0 ]; then SEV=2
elif [ "$OLDEST" -gt "$MAXH" ]; then SEV=1
else SEV=0; fi

if [ "$JSON" -eq 1 ]; then
  print_json backup oldest_age_hours "$OLDEST" "$MAXH" "$SEV"
else
  print_human backup oldest_age_hours "$OLDEST" "$MAXH" "$SEV"; echo "detail:$DETAIL found=$FOUND"
fi

if [ $SEV -ge 1 ]; then
  notify_email "备份状态异常" "oldest=${OLDEST}h max=${MAXH}h found=$FOUND detail=$DETAIL host=$(hostname_short)" || true
fi
exit $SEV