# 脚本名称：sec_check_world_writable_files.sh
# 用途：在关键目录中查找世界可写文件/目录，发现则告警
# 依赖：bash、find
# 权限：建议 root
# 参数：
#   --json                   以 JSON 输出发现数量
#   --paths p1,p2            覆盖扫描目录列表
# 环境变量：
#   SCAN_PATHS="/etc,/opt,/var/www"
# 退出码：0 无；1 有；2 严重（大量或出现在系统目录）；3 依赖缺失

set -u
. "$(dirname "$0")/../lib/common.sh"
load_env

require_cmd find || exit_missing_dep find

JSON=0; PATHS=${SCAN_PATHS:-/etc,/opt,/var/www}
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
  c=$(find "$p" -xdev \( -type f -o -type d \) -perm -0002 -not -path '*/tmp/*' 2>/dev/null | wc -l)
  COUNT=$((COUNT+c))
  [ "$c" -gt 0 ] && DETAIL="$DETAIL $p:$c"
done

SEV=0
if [ "$COUNT" -ge 50 ]; then SEV=2
elif [ "$COUNT" -gt 0 ]; then SEV=1
else SEV=0; fi

if [ "$JSON" -eq 1 ]; then
  print_json security world_writable "$COUNT" 0 "$SEV"
else
  print_human security world_writable "$COUNT" 0 "$SEV"; echo "detail:$DETAIL"
fi

if [ $SEV -ge 1 ]; then
  notify_email "世界可写风险" "count=$COUNT detail=$DETAIL host=$(hostname_short)" || true
fi
exit $SEV