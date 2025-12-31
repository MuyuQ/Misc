# 脚本名称：stg_check_nfs_mount_health.sh
# 用途：检查 NFS 挂载可用性（简单读测试），异常时告警
# 依赖：bash、mount 或 /proc/mounts、stat
# 权限：建议 root
# 参数：
#   --json                   以 JSON 输出异常挂载数量
# 环境变量：无
# 退出码：0 正常；1 异常；2 严重（多处异常）；3 依赖缺失

set -u
. "$(dirname "$0")/../lib/common.sh"
load_env

JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
  esac; shift || true
done

MOUNTS=$(awk '$3 ~ /nfs/ {print $2}' /proc/mounts 2>/dev/null)
ABN=0; DETAIL=""
for m in $MOUNTS; do
  stat "$m" >/dev/null 2>&1 || { ABN=$((ABN+1)); DETAIL="$DETAIL $m"; }
done

SEV=0
if [ "$ABN" -ge 3 ]; then SEV=2
elif [ "$ABN" -gt 0 ]; then SEV=1
else SEV=0; fi

if [ "$JSON" -eq 1 ]; then
  print_json nfs mount_abnormal "$ABN" 0 "$SEV"
else
  print_human nfs mount_abnormal "$ABN" 0 "$SEV"; echo "detail:$DETAIL"
fi

if [ $SEV -ge 1 ]; then
  notify_email "NFS 挂载异常" "count=$ABN detail=$DETAIL host=$(hostname_short)" || true
fi
exit $SEV