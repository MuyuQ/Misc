# 脚本名称：sys_check_time_sync.sh
# 用途：检查系统时间同步状态与漂移，异常时告警
# 依赖：bash、timedatectl；可选：chronyc、ntpq
# 权限：无需 root
# 参数：
#   --json               以 JSON 格式输出结果（同步=1/0，漂移秒）
# 环境变量：无
# 退出码：0 正常；1 警告（未同步或漂移较大）；2 严重（服务失效）；3 依赖缺失

set -u
. "$(dirname "$0")/../lib/common.sh"
load_env

JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
  esac; shift || true
done

require_cmd timedatectl || exit_missing_dep timedatectl

SYNC=$(timedatectl 2>/dev/null | awk -F ': ' '/System clock synchronized/ {print $2}')
NTP=$(timedatectl 2>/dev/null | awk -F ': ' '/NTP service/ {print $2}')
IS_SYNC=0; [ "$SYNC" = "yes" ] && IS_SYNC=1
SEV=0; [ "$IS_SYNC" -eq 0 ] && SEV=1; [ "$NTP" != "active" ] && SEV=2

DRIFT="NA"
if command -v chronyc >/dev/null 2>&1; then
  DRIFT=$(chronyc tracking | awk -F ': ' '/Last offset/ {print $2}' | awk '{print $1}')
elif command -v ntpq >/dev/null 2>&1; then
  DRIFT=$(ntpq -c rv | awk -F '=' '/offset/ {print $2}' | awk -F ',' '{print $1}')
fi

if [ "$JSON" -eq 1 ]; then
  print_json time sync "$IS_SYNC" 1 "$SEV"
else
  print_human time sync "$IS_SYNC" 1 "$SEV"; echo "NTP=$NTP drift=$DRIFT"
fi

if [ $SEV -ge 1 ]; then
  notify_email "时间同步异常" "sync=$IS_SYNC ntp=$NTP drift=$DRIFT host=$(hostname_short)" || true
fi
exit $SEV