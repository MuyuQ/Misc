# 脚本名称：net_check_unexpected_open_ports.sh
# 用途：检测开放端口是否超出允许基线，发现异常端口告警
# 依赖：bash、ss 或 netstat
# 权限：建议 root（获取完整监听列表），普通用户亦可
# 参数：
#   --json               以 JSON 格式输出异常端口数量
#   --allowed a,b,c      覆盖允许端口列表（逗号分隔）
# 环境变量：
#   ALLOWED_PORTS="22,80,443"
# 退出码：0 无异常；1 有异常；2 严重（异常端口过多）；3 依赖缺失

set -u
. "$(dirname "$0")/../lib/common.sh"
load_env

JSON=0; ALLOWED=${ALLOWED_PORTS:-22}
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
    --allowed) ALLOWED="$2"; shift ;;
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

ABNORMAL=0; DETAIL=""
for p in $LISTEN; do
  echo "$ALLOWED" | tr ',' '\n' | grep -wq "$p" || { ABNORMAL=$((ABNORMAL+1)); DETAIL="$DETAIL $p"; }
done

SEV=0
if [ "$ABNORMAL" -ge 5 ]; then SEV=2
elif [ "$ABNORMAL" -gt 0 ]; then SEV=1
else SEV=0; fi

if [ "$JSON" -eq 1 ]; then
  print_json ports unexpected "$ABNORMAL" 0 "$SEV"
else
  print_human ports unexpected "$ABNORMAL" 0 "$SEV"; echo "unexpected:$DETAIL"
fi

if [ $SEV -ge 1 ]; then
  notify_email "异常开放端口" "unexpected=$ABNORMAL detail=$DETAIL host=$(hostname_short)" || true
fi
exit $SEV