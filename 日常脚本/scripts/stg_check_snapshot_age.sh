# 脚本名称：stg_check_snapshot_age.sh
# 用途：检查 LVM/ZFS 快照年龄与数量限制，超限告警
# 依赖：bash、lvs 或 zfs
# 权限：建议 root
# 参数：
#   --json                   以 JSON 输出最老快照年龄（小时）
#   --max-age H              覆盖最大允许年龄（小时）
# 环境变量：
#   SNAPSHOT_MAX_AGE_HOURS=168
# 退出码：0 正常；1 过期；2 严重（大量过期）；3 依赖缺失

set -u
. "$(dirname "$0")/../lib/common.sh"
load_env

JSON=0; MAXH=${SNAPSHOT_MAX_AGE_HOURS:-168}
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
    --max-age) MAXH="$2"; shift ;;
  esac; shift || true
done

OLDEST=0; COUNT=0
now=$(date +%s)
if command -v lvs >/dev/null 2>&1; then
  while read -r name time; do
    ts=$(date -d "$time" +%s 2>/dev/null || echo $now)
    age=$(( (now-ts)/3600 ))
    [ "$age" -gt "$OLDEST" ] && OLDEST=$age
    COUNT=$((COUNT+1))
  done < <(lvs --noheadings --select 'lv_attr=~^s' -o lv_name,lv_time 2>/dev/null)
elif command -v zfs >/dev/null 2>&1; then
  while read -r snap time; do
    ts=$(date -d "$time" +%s 2>/dev/null || echo $now)
    age=$(( (now-ts)/3600 ))
    [ "$age" -gt "$OLDEST" ] && OLDEST=$age
    COUNT=$((COUNT+1))
  done < <(zfs list -t snapshot -o name,creation -H 2>/dev/null)
else
  exit_missing_dep lvs/zfs
fi

SEV=0
if [ "$COUNT" -eq 0 ]; then SEV=0
elif [ "$OLDEST" -gt "$MAXH" ]; then SEV=1
else SEV=0; fi

if [ "$JSON" -eq 1 ]; then
  print_json snapshot oldest_age_hours "$OLDEST" "$MAXH" "$SEV"
else
  print_human snapshot oldest_age_hours "$OLDEST" "$MAXH" "$SEV"; echo "count=$COUNT"
fi

if [ $SEV -ge 1 ]; then
  notify_email "快照年龄告警" "oldest=${OLDEST}h max=${MAXH}h count=$COUNT host=$(hostname_short)" || true
fi
exit $SEV