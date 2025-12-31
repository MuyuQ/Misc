# 脚本名称：sec_check_suid_sgid_binaries.sh
# 用途：发现新出现的 SUID/SGID 可执行文件并告警
# 依赖：bash、find
# 权限：建议 root
# 参数：
#   --json                   以 JSON 输出发现数量
#   --paths p1,p2            覆盖扫描目录列表
# 环境变量：
#   SCAN_PATHS="/usr,/bin,/sbin,/usr/local"
# 退出码：0 无；1 有；2 严重（大量或不可信路径）；3 依赖缺失

set -u
. "$(dirname "$0")/../lib/common.sh"
load_env

require_cmd find || exit_missing_dep find

JSON=0; PATHS=${SCAN_PATHS:-/usr,/bin,/sbin,/usr/local}
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
  c=$(find "$p" -xdev -type f -perm /6000 2>/dev/null | wc -l)
  COUNT=$((COUNT+c))
  [ "$c" -gt 0 ] && DETAIL="$DETAIL $p:$c"
done

SEV=0
if [ "$COUNT" -ge 20 ]; then SEV=2
elif [ "$COUNT" -gt 0 ]; then SEV=1
else SEV=0; fi

if [ "$JSON" -eq 1 ]; then
  print_json security suid_sgid "$COUNT" 0 "$SEV"
else
  print_human security suid_sgid "$COUNT" 0 "$SEV"; echo "detail:$DETAIL"
fi

if [ $SEV -ge 1 ]; then
  notify_email "SUID/SGID 风险" "count=$COUNT detail=$DETAIL host=$(hostname_short)" || true
fi
exit $SEV