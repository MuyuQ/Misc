# 脚本名称：sys_check_cgroup_psi.sh
# 用途：读取 /proc/pressure 的 CPU/MEM/IO PSI 指标，过载时告警
# 依赖：bash、/proc/pressure/*
# 权限：无需 root
# 参数：
#   --json                   以 JSON 输出 avg10 最大值
#   --warn N                 覆盖警告阈值（例如 0.5）
#   --crit N                 覆盖严重阈值（例如 0.8）
# 环境变量：
#   PSI_WARN=0.5 PSI_CRIT=0.8
# 退出码：0 正常；1 警告；2 严重；3 依赖缺失

set -u
. "$(dirname "$0")/../lib/common.sh"
load_env

JSON=0; WARN=${PSI_WARN:-0.5}; CRIT=${PSI_CRIT:-0.8}
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
    --warn) WARN="$2"; shift ;;
    --crit) CRIT="$2"; shift ;;
  esac; shift || true
done

max=0; detail=""
for f in cpu memory io; do
  FILE="/proc/pressure/$f"
  [ -r "$FILE" ] || exit_missing_dep pressure_$f
  val=$(awk '/avg10/ {for(i=1;i<=NF;i++){if($i ~ /avg10/) {split($i,a,"="); print a[2]}}}' "$FILE")
  # avg10 是百分比，转换为 0-1 范围
  p=$(awk -v v="$val" 'BEGIN{printf "%.2f", v/100.0}')
  detail="$detail $f:$p"
  awk -v x="$p" -v m="$max" 'BEGIN{if(x>m)exit 1}'; [ $? -eq 1 ] && max="$p"
done

SEV=0
awk -v v="$max" -v c="$CRIT" -v w="$WARN" 'BEGIN{if(v>=c)exit 2; else if(v>=w)exit 1; else exit 0}' >/dev/null 2>&1
RC=$?; if [ $RC -eq 2 ]; then SEV=2; elif [ $RC -eq 1 ]; then SEV=1; else SEV=0; fi

if [ "$JSON" -eq 1 ]; then
  print_json psi max_avg10 "$max" "$WARN" "$SEV"
else
  print_human psi max_avg10 "$max" "$WARN" "$SEV"; echo "detail:$detail"
fi

if [ $SEV -ge 1 ]; then
  notify_email "PSI 压力告警" "max=$max detail=$detail host=$(hostname_short)" || true
fi
exit $SEV