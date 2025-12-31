# 脚本名称：svc_check_systemd_services.sh
# 用途：检查关键 systemd 服务是否处于 active/running 状态
# 依赖：bash、systemctl 或 service
# 权限：建议 root（获取服务状态更完整），普通用户亦可
# 参数：
#   --json                 以 JSON 输出不健康服务数量
#   --services a,b,c       覆盖服务名列表（逗号分隔）
# 环境变量：
#   REQUIRED_SERVICES="sshd,cron"
# 退出码：0 全部健康；1 有不健康；2 严重（全部不健康）；3 依赖缺失

set -u
. "$(dirname "$0")/../lib/common.sh"
load_env

JSON=0; SVCS=${REQUIRED_SERVICES:-sshd}
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
    --services) SVCS="$2"; shift ;;
  esac; shift || true
done

UNHEALTHY=0; TOTAL=0; DETAIL=""
IFS=',' read -r -a arr <<< "$SVCS"
for s in "${arr[@]}"; do
  TOTAL=$((TOTAL+1))
  if command -v systemctl >/dev/null 2>&1; then
    st=$(systemctl is-active "$s" 2>/dev/null || echo unknown)
    [ "$st" = "active" ] || { UNHEALTHY=$((UNHEALTHY+1)); DETAIL="$DETAIL $s:$st"; }
  elif command -v service >/dev/null 2>&1; then
    service "$s" status >/dev/null 2>&1 || { UNHEALTHY=$((UNHEALTHY+1)); DETAIL="$DETAIL $s:down"; }
  else
    exit_missing_dep systemctl
  fi
done

SEV=0
if [ "$UNHEALTHY" -ge "$TOTAL" ]; then SEV=2
elif [ "$UNHEALTHY" -gt 0 ]; then SEV=1
else SEV=0; fi

if [ "$JSON" -eq 1 ]; then
  print_json service unhealthy "$UNHEALTHY" 0 "$SEV"
else
  print_human service unhealthy "$UNHEALTHY" 0 "$SEV"; echo "detail:$DETAIL"
fi

if [ $SEV -ge 1 ]; then
  notify_email "服务不健康" "unhealthy=$UNHEALTHY detail=$DETAIL host=$(hostname_short)" || true
fi
exit $SEV