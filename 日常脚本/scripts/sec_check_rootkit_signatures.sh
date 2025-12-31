# 脚本名称：sec_check_rootkit_signatures.sh
# 用途：调用 rkhunter/chkrootkit 检查可疑 rootkit 特征
# 依赖：bash、rkhunter 或 chkrootkit
# 权限：建议 root
# 参数：
#   --json                   以 JSON 输出可疑项数量
# 环境变量：无
# 退出码：0 正常；1 可疑；2 严重（大量可疑或工具失败）；3 依赖缺失

set -u
. "$(dirname "$0")/../lib/common.sh"
load_env

JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
  esac; shift || true
done

COUNT=0; TOOL=""
if command -v rkhunter >/dev/null 2>&1; then
  TOOL=rkhunter
  OUT=$(rkhunter --check --sk 2>/dev/null)
  COUNT=$(printf "%s" "$OUT" | grep -c '\[ Warning \]')
elif command -v chkrootkit >/dev/null 2>&1; then
  TOOL=chkrootkit
  OUT=$(chkrootkit 2>/dev/null)
  COUNT=$(printf "%s" "$OUT" | grep -ci 'INFECTED')
else
  exit_missing_dep rkhunter/chkrootkit
fi

SEV=0
if [ "$COUNT" -ge 5 ]; then SEV=2
elif [ "$COUNT" -gt 0 ]; then SEV=1
else SEV=0; fi

if [ "$JSON" -eq 1 ]; then
  print_json security rootkit_hits "$COUNT" 0 "$SEV"
else
  print_human security rootkit_hits "$COUNT" 0 "$SEV"; echo "tool=$TOOL"
fi

if [ $SEV -ge 1 ]; then
  notify_email "Rootkit 可疑" "hits=$COUNT tool=$TOOL host=$(hostname_short)" || true
fi
exit $SEV