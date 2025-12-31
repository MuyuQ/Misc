# 脚本名称：sys_check_sensors_temp.sh
# 用途：读取硬件温度（sensors），超过阈值告警
# 依赖：bash、sensors（lm-sensors）
# 权限：无需 root
# 参数：
#   --json               以 JSON 格式输出最高温度（摄氏度）
#   --warn N             覆盖警告阈值（摄氏度）
#   --crit N             覆盖严重阈值（摄氏度）
# 环境变量：
#   TEMP_WARN_C=80 TEMP_CRIT_C=90
# 退出码：0 正常；1 警告；2 严重；3 依赖缺失

set -u
. "$(dirname "$0")/../lib/common.sh"
load_env

JSON=0; WARN=${TEMP_WARN_C:-80}; CRIT=${TEMP_CRIT_C:-90}
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
    --warn) WARN="$2"; shift ;;
    --crit) CRIT="$2"; shift ;;
  esac; shift || true
done

command -v sensors >/dev/null 2>&1 || exit_missing_dep sensors

MAX=0
while read -r line; do
  val=$(echo "$line" | grep -Eo '\+[0-9]+\.[0-9]+' | tr -d '+')
  if [ -n "$val" ]; then
    v=$(printf %.0f "$val")
    [ "$v" -gt "$MAX" ] && MAX="$v"
  fi
done < <(sensors)

SEV=0
if [ "$MAX" -ge "$CRIT" ]; then SEV=2
elif [ "$MAX" -ge "$WARN" ]; then SEV=1
else SEV=0; fi

if [ "$JSON" -eq 1 ]; then
  print_json hardware max_temp_c "$MAX" "$WARN" "$SEV"
else
  print_human hardware max_temp_c "$MAX" "$WARN" "$SEV"
fi

if [ $SEV -ge 1 ]; then
  notify_email "硬件温度告警" "temp_c=$MAX warn=$WARN crit=$CRIT host=$(hostname_short)" || true
fi
exit $SEV