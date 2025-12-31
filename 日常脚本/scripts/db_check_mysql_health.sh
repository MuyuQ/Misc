# 脚本名称：db_check_mysql_health.sh
# 用途：检查 MySQL 连接数与复制延迟等基本健康指标
# 依赖：bash、mysql 客户端
# 权限：无需 root
# 参数：
#   --json                   以 JSON 输出连接数与复制延迟
# 环境变量：
#   MYSQL_HOST=127.0.0.1 MYSQL_PORT=3306 MYSQL_USER=root MYSQL_PASS= MYSQL_CONN_WARN=200 MYSQL_CONN_CRIT=400
# 退出码：0 正常；1 警告；2 严重；3 依赖缺失/连接失败

set -u
. "$(dirname "$0")/../lib/common.sh"
load_env

command -v mysql >/dev/null 2>&1 || exit_missing_dep mysql

JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
  esac; shift || true
done

HOST=${MYSQL_HOST:-127.0.0.1}; PORT=${MYSQL_PORT:-3306}; USER=${MYSQL_USER:-root}; PASS=${MYSQL_PASS:-}
WARN=${MYSQL_CONN_WARN:-200}; CRIT=${MYSQL_CONN_CRIT:-400}

AUTH=( -h "$HOST" -P "$PORT" -u "$USER" )
[ -n "$PASS" ] && AUTH+=( -p"$PASS" )

CONN=$(mysql "${AUTH[@]}" -e "SHOW STATUS LIKE 'Threads_connected';" 2>/dev/null | awk '/Threads_connected/ {print $2}')
SLAVE=$(mysql "${AUTH[@]}" -e "SHOW SLAVE STATUS\G" 2>/dev/null | awk -F ': ' '/Seconds_Behind_Master/ {print $2}')
if [ -z "$CONN" ]; then
  exit 3
fi
[ -z "$SLAVE" ] && SLAVE="NA"

SEV=0
if [ "$CONN" -ge "$CRIT" ]; then SEV=2
elif [ "$CONN" -ge "$WARN" ]; then SEV=1
else SEV=0; fi

if [ "$JSON" -eq 1 ]; then
  print_json mysql threads_connected "$CONN" "$WARN" "$SEV"; echo "{""replication_lag"":""$SLAVE""}"
else
  print_human mysql threads_connected "$CONN" "$WARN" "$SEV"; echo "replication_lag=$SLAVE"
fi

if [ $SEV -ge 1 ]; then
  notify_email "MySQL 连接数告警" "conn=$CONN lag=$SLAVE host=$(hostname_short)" || true
fi
exit $SEV