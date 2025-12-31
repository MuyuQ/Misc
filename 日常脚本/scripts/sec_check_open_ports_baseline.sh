# 脚本名称：sec_check_open_ports_baseline.sh
# 用途：开放端口与基线比对（允许集合、必需集合），存在差异时告警
# 依赖：bash、ss 或 netstat
# 权限：建议 root
# 参数：
#   --json                   以 JSON 输出差异数量
#   --allowed a,b,c          覆盖允许端口列表
#   --required a,b,c         覆盖必需端口列表
# 环境变量：
#   ALLOWED_PORTS="22,80,443" REQUIRED_PORTS="22,80,443"
# 退出码：0 无差异；1 有差异；2 严重（大量差异）；3 依赖缺失

set -u
. "$(dirname "$0")/../lib/common.sh"
load_env

JSON=0; ALLOWED=${ALLOWED_PORTS:-22}; REQUIRED=${REQUIRED_PORTS:-22}
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
    --allowed) ALLOWED="$2"; shift ;;
    --required) REQUIRED="$2"; shift ;;
  esac; shift || true
done

LISTEN=""
if command -v ss >/dev/null 2>&1; then
  LISTEN=$(ss -lnt | awk 'NR>1 {print $4}' | awk -F ':' '{print $NF}' | sort -u)
elif command -v netstat >/dev/null 2>&1; then
  LISTEN=$(netstat -lnt | awk 'NR>2 {print $4}' | awk -F ':' '{print $NF}' | sort -u)
else
  exit_missing_dep ss
fi

DIFF=0; DETAIL=""
# 必需缺失
for p in $(echo "$REQUIRED" | tr ',' '\n'); do
  echo "$LISTEN" | grep -wq "$p" || { DIFF=$((DIFF+1)); DETAIL="$DETAIL missing:$p"; }
done
# 不允许存在
for p in $LISTEN; do
  echo "$ALLOWED" | tr ',' '\n' | grep -wq "$p" || { DIFF=$((DIFF+1)); DETAIL="$DETAIL unexpected:$p"; }
done

SEV=0
if [ "$DIFF" -ge 5 ]; then SEV=2
elif [ "$DIFF" -gt 0 ]; then SEV=1
else SEV=0; fi

if [ "$JSON" -eq 1 ]; then
  print_json ports baseline_diff "$DIFF" 0 "$SEV"
else
  print_human ports baseline_diff "$DIFF" 0 "$SEV"; echo "detail:$DETAIL"
fi

if [ $SEV -ge 1 ]; then
  notify_email "端口基线差异" "diff=$DIFF detail=$DETAIL host=$(hostname_short)" || true
fi
exit $SEV