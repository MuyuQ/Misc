# 脚本名称：k8s_check_node_status.sh
# 用途：检查 Kubernetes 节点就绪状态与污点，异常时告警
# 依赖：bash、kubectl
# 权限：无需 root（需要 kubeconfig）
# 参数：
#   --json                   以 JSON 输出异常节点数量
# 环境变量：无
# 退出码：0 正常；1 异常；2 严重（大量异常）；3 依赖缺失

set -u
. "$(dirname "$0")/../lib/common.sh"
load_env

command -v kubectl >/dev/null 2>&1 || exit_missing_dep kubectl

JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
  esac; shift || true
done

ABN=0; DETAIL=""
OUT=$(kubectl get nodes 2>/dev/null | awk 'NR>1 {print $1,$2}')
while read -r name status; do
  echo "$status" | grep -qi 'Ready' || { ABN=$((ABN+1)); DETAIL="$DETAIL $name:$status"; }
done <<EOF
$OUT
EOF

SEV=0
if [ "$ABN" -ge 2 ]; then SEV=2
elif [ "$ABN" -gt 0 ]; then SEV=1
else SEV=0; fi

if [ "$JSON" -eq 1 ]; then
  print_json k8s nodes_abnormal "$ABN" 0 "$SEV"
else
  print_human k8s nodes_abnormal "$ABN" 0 "$SEV"; echo "detail:$DETAIL"
fi

if [ $SEV -ge 1 ]; then
  notify_email "K8s 节点异常" "count=$ABN detail=$DETAIL host=$(hostname_short)" || true
fi
exit $SEV