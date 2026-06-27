#!/bin/bash
# 脚本名称：db_check_redis_health.sh
# 用途：检查 Redis 内存占用与驱逐率，异常时告警
# 依赖：bash、redis-cli
# 权限：无需 root
# 参数：
#   --json                   以 JSON 输出关键指标
# 环境变量：
#   REDIS_HOST=127.0.0.1 REDIS_PORT=6379 REDIS_MEM_WARN_MB=1024 REDIS_MEM_CRIT_MB=2048
# 退出码：0 正常；1 警告；2 严重；3 依赖缺失/连接失败

set -euo pipefail
. "$(dirname "$0")/../lib/common.sh"
load_env
DESCRIPTION="检查 Redis 内存占用与驱逐率，异常时告警"

command -v redis-cli >/dev/null 2>&1 || exit_missing_dep redis-cli

JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
    --help|-h) print_help; exit 0 ;;
  esac; shift || true
done

HOST=${REDIS_HOST:-127.0.0.1}; PORT=${REDIS_PORT:-6379}
WARN=${REDIS_MEM_WARN_MB:-1024}; CRIT=${REDIS_MEM_CRIT_MB:-2048}

INFO=$(redis-cli -h "$HOST" -p "$PORT" INFO memory 2>/dev/null)
[ -z "$INFO" ] && exit 3
MEM_BYTES=$(echo "$INFO" | awk -F ':' '/^used_memory:/ {print $2}' | tr -d '\r')
MEM_MB=$(( ${MEM_BYTES:-0} / 1024 / 1024 ))
EVICT=$(redis-cli -h "$HOST" -p "$PORT" INFO stats 2>/dev/null | awk -F ':' '/evicted_keys/ {print $2}' | tr -d '\r')

SEV=0
if [ "$MEM_MB" -ge "${CRIT}" ]; then SEV=2
elif [ "$MEM_MB" -ge "${WARN}" ]; then SEV=1
else SEV=0; fi

if [ "$JSON" -eq 1 ]; then
  print_json redis used_memory_mb "$MEM_MB" "$WARN" "$SEV"
else
  print_human redis used_memory_mb "$MEM_MB" "$WARN" "$SEV"; echo "evicted_keys=${EVICT:-0}"
fi

if [ $SEV -ge 1 ]; then
  notify_email "Redis 内存告警" "mem_mb=$MEM_MB evicted=${EVICT:-0} host=$(hostname_short)" || true
fi
exit $SEV