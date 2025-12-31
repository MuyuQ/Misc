# 脚本名称：log_monitor_app_log_patterns.sh
# 用途：按配置正则扫描应用日志，匹配到错误模式时告警
# 依赖：bash、grep、awk
# 权限：无需 root（取决于日志路径权限）
# 参数：
#   --json                   以 JSON 输出匹配条目数量
#   --paths p1,p2            覆盖日志路径列表
#   --patterns r1,r2         覆盖正则模式列表
# 环境变量：
#   APP_LOG_PATHS="/var/log/app/app.log"
#   APP_LOG_PATTERNS="ERROR,CRITICAL,Exception"
# 退出码：0 无匹配；1 有匹配；2 严重（大量匹配）；3 依赖缺失

set -u
. "$(dirname "$0")/../lib/common.sh"
load_env

JSON=0; PATHS=${APP_LOG_PATHS:-/var/log/app/app.log}; PATS=${APP_LOG_PATTERNS:-ERROR}
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
    --paths) PATHS="$2"; shift ;;
    --patterns) PATS="$2"; shift ;;
  esac; shift || true
done

COUNT=0; DETAIL=""
IFS=',' read -r -a parr <<< "$PATHS"
IFS=',' read -r -a rarr <<< "$PATS"
for p in "${parr[@]}"; do
  [ -r "$p" ] || continue
  for r in "${rarr[@]}"; do
    c=$(grep -E "$r" "$p" 2>/dev/null | wc -l)
    COUNT=$((COUNT+c))
    [ "$c" -gt 0 ] && DETAIL="$DETAIL $p:$r:$c"
  done
done

SEV=0
if [ "$COUNT" -ge 100 ]; then SEV=2
elif [ "$COUNT" -gt 0 ]; then SEV=1
else SEV=0; fi

if [ "$JSON" -eq 1 ]; then
  print_json applog pattern_hits "$COUNT" 0 "$SEV"
else
  print_human applog pattern_hits "$COUNT" 0 "$SEV"; echo "detail:$DETAIL"
fi

if [ $SEV -ge 1 ]; then
  notify_email "应用日志错误" "hits=$COUNT detail=$DETAIL host=$(hostname_short)" || true
fi
exit $SEV