# 脚本名称：ctr_check_docker_container_health.sh
# 用途：检查 Docker 容器健康状态与重启次数，异常时告警
# 依赖：bash、docker
# 权限：建议 root 或 docker 组权限
# 参数：
#   --json                   以 JSON 输出不健康容器数量
# 环境变量：无
# 退出码：0 正常；1 异常；2 严重（大量异常）；3 依赖缺失

set -u
. "$(dirname "$0")/../lib/common.sh"
load_env

command -v docker >/dev/null 2>&1 || exit_missing_dep docker

JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
  esac; shift || true
done

ABN=0; DETAIL=""
for id in $(docker ps -q); do
  st=$(docker inspect -f '{{.State.Health.Status}}' "$id" 2>/dev/null || echo "unknown")
  rc=$(docker inspect -f '{{.RestartCount}}' "$id" 2>/dev/null || echo 0)
  name=$(docker inspect -f '{{.Name}}' "$id" | tr -d '/')
  if [ "$st" != "healthy" ] || [ "$rc" -ge 3 ]; then
    ABN=$((ABN+1)); DETAIL="$DETAIL $name:$st:restart=$rc"
  fi
done

SEV=0
if [ "$ABN" -ge 5 ]; then SEV=2
elif [ "$ABN" -gt 0 ]; then SEV=1
else SEV=0; fi

if [ "$JSON" -eq 1 ]; then
  print_json docker unhealthy "$ABN" 0 "$SEV"
else
  print_human docker unhealthy "$ABN" 0 "$SEV"; echo "detail:$DETAIL"
fi

if [ $SEV -ge 1 ]; then
  notify_email "Docker 容器异常" "count=$ABN detail=$DETAIL host=$(hostname_short)" || true
fi
exit $SEV