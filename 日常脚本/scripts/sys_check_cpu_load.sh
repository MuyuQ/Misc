# 脚本名称：sys_check_cpu_load.sh
# 用途：检查系统负载与 CPU 使用率，超阈值时发送邮件告警
# 依赖：bash、uptime、awk；可选：mpstat（sysstat）
# 权限：无需 root（建议普通用户运行）
# 参数：
#   --json            以 JSON 格式输出结果
#   --threshold N     自定义负载告警阈值（覆盖环境变量 CPU_LOAD_WARN/CRIT）
# 环境变量：
#   CPU_LOAD_WARN=4.0 CPU_LOAD_CRIT=8.0
#   SMTP_HOST/PORT/USER/PASS/MAIL_TO 邮件配置
# 退出码：0 正常；1 警告；2 严重；3 依赖缺失
# 示例：
#   ./scripts/check_cpu_load.sh --json

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

require_cmd uptime || exit_missing_dep uptime

# 读取 1 分钟负载均值
LOAD1=$(uptime | awk -F 'load average: ' '{print $2}' | awk -F ', ' '{print $1}' | tr -d ' ')
WARN=${THRESH:-${CPU_LOAD_WARN:-4.0}}
CRIT=${CPU_LOAD_CRIT:-8.0}

SEV=0
awk "BEGIN{if($LOAD1>=$CRIT)exit 2; else if($LOAD1>=$WARN)exit 1; else exit 0;}" >/dev/null 2>&1
RC=$?
if [ $RC -eq 2 ]; then SEV=2; elif [ $RC -eq 1 ]; then SEV=1; else SEV=0; fi

if [ "$JSON" -eq 1 ]; then
  print_json cpu load1 "$LOAD1" "$WARN" "$SEV"
else
  print_human cpu load1 "$LOAD1" "$WARN" "$SEV"
fi

if [ $SEV -ge 1 ]; then
  notify_email "CPU 负载告警" "load1=$LOAD1 warn=$WARN crit=$CRIT host=$(hostname_short)" || true
fi

exit $SEV