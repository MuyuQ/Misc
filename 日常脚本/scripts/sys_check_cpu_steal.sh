# 脚本名称：sys_check_cpu_steal.sh
# 用途：检测 CPU steal time（虚拟化争用），超阈值时告警
# 依赖：bash、mpstat（sysstat）或 /proc/stat
# 权限：无需 root
# 参数：
#   --json            以 JSON 格式输出结果
#   --threshold N     自定义 steal 比例告警阈值（百分比）
# 环境变量：
#   CPU_STEAL_WARN=5 CPU_STEAL_CRIT=10
# 退出码：0 正常；1 警告；2 严重；3 依赖缺失

set -u
. "$(dirname "$0")/../lib/common.sh"
load_env

JSON=0
THRESH=""
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
    --threshold) THRESH="$2"; shift ;;
  esac
  shift || true
done

STEAL=0
if command -v mpstat >/dev/null 2>&1; then
  STEAL=$(mpstat 1 1 | awk '/Average:/ {print $NF}')
else
  # 简化估算：读取 /proc/stat 两次计算 steal 差值比率
  read -r cpu1 user1 nice1 sys1 idle1 iow1 irq1 soft1 steal1 guest1 guestn1 < /proc/stat
  sleep 1
  read -r cpu2 user2 nice2 sys2 idle2 iow2 irq2 soft2 steal2 guest2 guestn2 < /proc/stat
  total=$(( (user2-user1)+(nice2-nice1)+(sys2-sys1)+(idle2-idle1)+(iow2-iow1)+(irq2-irq1)+(soft2-soft1)+(steal2-steal1) ))
  st=$(( steal2-steal1 ))
  STEAL=$(awk -v s="$st" -v t="$total" 'BEGIN{if(t==0)print 0; else printf "%.2f", (s*100.0)/t}')
fi

WARN=${THRESH:-${CPU_STEAL_WARN:-5}}
CRIT=${CPU_STEAL_CRIT:-10}

SEV=0
awk "BEGIN{if($STEAL>=$CRIT)exit 2; else if($STEAL>=$WARN)exit 1; else exit 0;}" >/dev/null 2>&1
RC=$?
if [ $RC -eq 2 ]; then SEV=2; elif [ $RC -eq 1 ]; then SEV=1; else SEV=0; fi

if [ "$JSON" -eq 1 ]; then
  print_json cpu steal_percent "$STEAL" "$WARN" "$SEV"
else
  print_human cpu steal_percent "$STEAL" "$WARN" "$SEV"
fi

if [ $SEV -ge 1 ]; then
  notify_email "CPU Steal 告警" "steal%=$STEAL warn=$WARN crit=$CRIT host=$(hostname_short)" || true
fi

exit $SEV