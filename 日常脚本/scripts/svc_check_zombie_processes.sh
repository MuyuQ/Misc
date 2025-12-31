# 脚本名称：svc_check_zombie_processes.sh
# 用途：统计僵尸进程数量并定位父进程，发现则告警
# 依赖：bash、ps、awk
# 权限：无需 root
# 参数：
#   --json                 以 JSON 输出僵尸进程数量
# 环境变量：无
# 退出码：0 无僵尸；1 有僵尸；2 严重（僵尸数量过多）；3 依赖缺失

set -u
. "$(dirname "$0")/../lib/common.sh"
load_env

require_cmd ps || exit_missing_dep ps

JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
  esac; shift || true
done

ZCNT=$(ps axo stat,ppid,pid,comm --no-headers | awk '$1 ~ /Z/ {print $0}' | wc -l)
DETAIL=$(ps axo stat,ppid,pid,comm --no-headers | awk '$1 ~ /Z/ {print "pid=" $3 " ppid=" $2 " " $4}' | head -n 5)

SEV=0
if [ "$ZCNT" -ge 10 ]; then SEV=2
elif [ "$ZCNT" -gt 0 ]; then SEV=1
else SEV=0; fi

if [ "$JSON" -eq 1 ]; then
  print_json process zombies "$ZCNT" 0 "$SEV"
else
  print_human process zombies "$ZCNT" 0 "$SEV"; echo "$DETAIL"
fi

if [ $SEV -ge 1 ]; then
  notify_email "僵尸进程告警" "count=$ZCNT detail=$(echo "$DETAIL" | tr '\n' '; ') host=$(hostname_short)" || true
fi
exit $SEV