# 脚本名称：db_check_postgres_health.sh
# 用途：检查 PostgreSQL 连接数与复制状态等基本健康指标
# 依赖：bash、psql 客户端
# 权限：无需 root
# 参数：
#   --json                   以 JSON 输出连接数
# 环境变量：
#   PGHOST=127.0.0.1 PGPORT=5432 PGUSER=postgres PGPASSWORD= PG_CONN_WARN=200 PG_CONN_CRIT=400
# 退出码：0 正常；1 警告；2 严重；3 依赖缺失/连接失败

set -u
. "$(dirname "$0")/../lib/common.sh"
load_env

command -v psql >/dev/null 2>&1 || exit_missing_dep psql

JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
  esac; shift || true
done

export PGHOST=${PGHOST:-127.0.0.1}
export PGPORT=${PGPORT:-5432}
export PGUSER=${PGUSER:-postgres}
export PGPASSWORD=${PGPASSWORD:-}
WARN=${PG_CONN_WARN:-200}; CRIT=${PG_CONN_CRIT:-400}

CONN=$(psql -tAc "SELECT count(*) FROM pg_stat_activity;" 2>/dev/null)
[ -z "$CONN" ] && exit 3

SEV=0
if [ "$CONN" -ge "$CRIT" ]; then SEV=2
elif [ "$CONN" -ge "$WARN" ]; then SEV=1
else SEV=0; fi

if [ "$JSON" -eq 1 ]; then
  print_json postgres connections "$CONN" "$WARN" "$SEV"
else
  print_human postgres connections "$CONN" "$WARN" "$SEV"
fi

if [ $SEV -ge 1 ]; then
  notify_email "PostgreSQL 连接数告警" "conn=$CONN host=$(hostname_short)" || true
fi
exit $SEV