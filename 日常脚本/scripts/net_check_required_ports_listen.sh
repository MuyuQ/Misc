# 脚本名称：net_check_required_ports_listen.sh
# 用途：检查必需端口是否处于监听状态
# 依赖：bash、ss 或 netstat
# 权限：建议 root（获取完整监听列表），普通用户亦可
# 参数：
#   --json               以 JSON 格式输出缺失端口数量
#   --ports a,b,c        覆盖必需端口列表（逗号分隔）
# 环境变量：
#   REQUIRED_PORTS="22,80,443"
# 退出码：0 全部监听；1 有缺失；2 严重（全部缺失）；3 依赖缺失

set -u
. "$(dirname "$0")/../lib/common.sh"
load_env

JSON=0; PORTS=${REQUIRED_PORTS:-22}
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
    --ports) PORTS="$2"; shift ;;
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

MISSING=0; TOTAL=0; DETAIL=""
IFS=',' read -r -a arr <<< "$PORTS"
for p in "${arr[@]}"; do
  TOTAL=$((TOTAL+1))
  echo "$LISTEN" | grep -wq "$p" || { MISSING=$((MISSING+1)); DETAIL="$DETAIL $p"; }
done

SEV=0
if [ "$MISSING" -ge "$TOTAL" ]; then SEV=2
elif [ "$MISSING" -gt 0 ]; then SEV=1
else SEV=0; fi

if [ "$JSON" -eq 1 ]; then
  print_json ports missing "$MISSING" 0 "$SEV"
else
  print_human ports missing "$MISSING" 0 "$SEV"; echo "missing:$DETAIL"
fi

if [ $SEV -ge 1 ]; then
  notify_email "端口监听缺失" "missing=$MISSING detail=$DETAIL host=$(hostname_short)" || true
fi
exit $SEV