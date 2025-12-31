# 脚本名称：svc_check_process_flapping.sh
# 用途：检测关键服务是否短时间内频繁重启（抖动）
# 依赖：bash、journalctl 或 systemctl
# 权限：建议 root（读取完整日志）
# 参数：
#   --json                 以 JSON 输出发现的抖动服务数量
#   --services a,b,c       覆盖服务名列表（逗号分隔）
# 环境变量：
#   REQUIRED_SERVICES="sshd,cron"
# 退出码：0 无抖动；1 有抖动；2 严重（多服务抖动）；3 依赖缺失

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

require_cmd journalctl || require_cmd systemctl || exit_missing_dep journalctl

FLAP=0; DETAIL=""
IFS=',' read -r -a arr <<< "$SVCS"
for s in "${arr[@]}"; do
  if command -v journalctl >/dev/null 2>&1; then
    cnt=$(journalctl -u "$s" --since "-10 min" 2>/dev/null | grep -Ei 'Starting|Stopped|Restarting|start request repeated too quickly' | wc -l)
  else
    cnt=$(systemctl status "$s" 2>/dev/null | grep -Ei 'start request repeated too quickly' | wc -l)
  fi
  if [ "$cnt" -ge 3 ]; then FLAP=$((FLAP+1)); DETAIL="$DETAIL $s:$cnt"; fi
done

SEV=0
if [ "$FLAP" -ge 3 ]; then SEV=2
elif [ "$FLAP" -gt 0 ]; then SEV=1
else SEV=0; fi

if [ "$JSON" -eq 1 ]; then
  print_json service flapping "$FLAP" 0 "$SEV"
else
  print_human service flapping "$FLAP" 0 "$SEV"; echo "detail:$DETAIL"
fi

if [ $SEV -ge 1 ]; then
  notify_email "服务抖动告警" "flapping=$FLAP detail=$DETAIL host=$(hostname_short)" || true
fi
exit $SEV