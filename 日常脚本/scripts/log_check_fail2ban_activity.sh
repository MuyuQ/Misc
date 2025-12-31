# 脚本名称：log_check_fail2ban_activity.sh
# 用途：检查 fail2ban 运行状态与封禁计数，异常时告警
# 依赖：bash、fail2ban-client
# 权限：建议 root
# 参数：
#   --json                 以 JSON 输出总封禁数量
# 环境变量：无
# 退出码：0 正常；1 有封禁（提示审查）；2 严重（封禁激增/服务异常）；3 依赖缺失

set -u
. "$(dirname "$0")/../lib/common.sh"
load_env

JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
  esac; shift || true
done

command -v fail2ban-client >/dev/null 2>&1 || exit_missing_dep fail2ban-client

JAILS=$(fail2ban-client status 2>/dev/null | awk -F ': ' '/Jail list/ {print $2}' | sed 's/, /\n/g')
TOTAL=0; DETAIL=""; SEV=0
for j in $JAILS; do
  b=$(fail2ban-client status "$j" 2>/dev/null | awk -F ': ' '/Total banned/ {print $2}')
  TOTAL=$((TOTAL + ${b:-0}))
  DETAIL="$DETAIL $j:${b:-0}"
done
if [ "$TOTAL" -ge 50 ]; then SEV=2
elif [ "$TOTAL" -gt 0 ]; then SEV=1
else SEV=0; fi

if [ "$JSON" -eq 1 ]; then
  print_json fail2ban total_banned "$TOTAL" 0 "$SEV"
else
  print_human fail2ban total_banned "$TOTAL" 0 "$SEV"; echo "detail:$DETAIL"
fi

if [ $SEV -ge 1 ]; then
  notify_email "Fail2ban 活动告警" "total=$TOTAL detail=$DETAIL host=$(hostname_short)" || true
fi
exit $SEV