# 脚本名称：svc_check_core_dumps.sh
# 用途：检查最近出现的核心转储文件（core dump），发现则告警
# 依赖：bash、find
# 权限：建议 root（遍历系统目录）
# 参数：
#   --json                 以 JSON 输出发现数量
#   --paths p1,p2          覆盖检查路径列表（逗号分隔）
# 环境变量：
#   CORE_PATHS="/var/lib/systemd/coredump,/tmp"
# 退出码：0 无；1 有；2 严重（数量很多）；3 依赖缺失

set -u
. "$(dirname "$0")/../lib/common.sh"
load_env

require_cmd find || exit_missing_dep find

JSON=0; PATHS=${CORE_PATHS:-/var/lib/systemd/coredump,/tmp}
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
    --paths) PATHS="$2"; shift ;;
  esac; shift || true
done

COUNT=0; DETAIL=""
IFS=',' read -r -a arr <<< "$PATHS"
for p in "${arr[@]}"; do
  [ -d "$p" ] || continue
  c=$(find "$p" -maxdepth 1 -type f -name 'core*' -mtime -1 2>/dev/null | wc -l)
  COUNT=$((COUNT+c))
  [ "$c" -gt 0 ] && DETAIL="$DETAIL $p:$c"
done

SEV=0
if [ "$COUNT" -ge 10 ]; then SEV=2
elif [ "$COUNT" -gt 0 ]; then SEV=1
else SEV=0; fi

if [ "$JSON" -eq 1 ]; then
  print_json core dumps "$COUNT" 0 "$SEV"
else
  print_human core dumps "$COUNT" 0 "$SEV"; echo "detail:$DETAIL"
fi

if [ $SEV -ge 1 ]; then
  notify_email "核心转储告警" "count=$COUNT detail=$DETAIL host=$(hostname_short)" || true
fi
exit $SEV