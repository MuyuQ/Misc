# 脚本名称：sys_check_entropy_pool.sh
# 用途：检查系统熵池可用性，低于阈值告警
# 依赖：bash、/proc/sys/kernel/random/entropy_avail
# 权限：无需 root
# 参数：
#   --json               以 JSON 格式输出可用熵值
#   --warn N             覆盖警告阈值
#   --crit N             覆盖严重阈值
# 环境变量：
#   ENTROPY_WARN=512 ENTROPY_CRIT=256
# 退出码：0 正常；1 警告；2 严重；3 依赖缺失

set -u
. "$(dirname "$0")/../lib/common.sh"
load_env

JSON=0; WARN=${ENTROPY_WARN:-512}; CRIT=${ENTROPY_CRIT:-256}
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
    --warn) WARN="$2"; shift ;;
    --crit) CRIT="$2"; shift ;;
  esac; shift || true
done

FILE=/proc/sys/kernel/random/entropy_avail
[ -r "$FILE" ] || exit_missing_dep entropy_avail
VAL=$(cat "$FILE")

SEV=0
if [ "$VAL" -le "$CRIT" ]; then SEV=2
elif [ "$VAL" -le "$WARN" ]; then SEV=1
else SEV=0; fi

if [ "$JSON" -eq 1 ]; then
  print_json entropy available "$VAL" "$WARN" "$SEV"
else
  print_human entropy available "$VAL" "$WARN" "$SEV"
fi

if [ $SEV -ge 1 ]; then
  notify_email "熵池不足" "entropy=$VAL warn=$WARN crit=$CRIT host=$(hostname_short)" || true
fi
exit $SEV