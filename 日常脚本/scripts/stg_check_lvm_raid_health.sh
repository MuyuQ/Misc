# 脚本名称：stg_check_lvm_raid_health.sh
# 用途：检查 LVM 与 mdadm RAID 的健康状态，降级/失效告警
# 依赖：bash、lvs 或 mdadm
# 权限：建议 root
# 参数：
#   --json                   以 JSON 输出异常卷/阵列数量
# 环境变量：无
# 退出码：0 正常；1 有异常；2 严重（多处异常）；3 依赖缺失

set -u
. "$(dirname "$0")/../lib/common.sh"
load_env

JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
  esac; shift || true
done

ABN=0; DETAIL=""
if command -v lvs >/dev/null 2>&1; then
  # 某些发行版支持 lv_health_status
  OUT=$(lvs --noheadings -o lv_name,lv_health_status 2>/dev/null)
  if [ -n "$OUT" ]; then
    c=$(echo "$OUT" | awk '$2!="" && tolower($2)!="healthy" {print $0}' | wc -l)
    ABN=$((ABN+c)); DETAIL="$DETAIL LVM:$c"
  else
    OUT=$(lvs --noheadings -o lv_name,lv_attr 2>/dev/null)
    c=$(echo "$OUT" | awk '$2!~/.*/ {print 0}' | wc -l)
    ABN=$((ABN+c)); DETAIL="$DETAIL LVM:$c"
  fi
fi

if command -v mdadm >/dev/null 2>&1; then
  OUT=$(mdadm --detail --scan 2>/dev/null)
  for a in $(echo "$OUT" | awk '/ARRAY/ {print $2}'); do
    st=$(mdadm --detail "$a" 2>/dev/null | awk -F ': ' '/State/ {print $2}')
    echo "$st" | grep -qi 'degraded\|faulty' && { ABN=$((ABN+1)); DETAIL="$DETAIL mdadm:$a:$st"; }
  done
fi

SEV=0
if [ "$ABN" -ge 3 ]; then SEV=2
elif [ "$ABN" -gt 0 ]; then SEV=1
else SEV=0; fi

if [ "$JSON" -eq 1 ]; then
  print_json storage lvm_raid_abnormal "$ABN" 0 "$SEV"
else
  print_human storage lvm_raid_abnormal "$ABN" 0 "$SEV"; echo "detail:$DETAIL"
fi

if [ $SEV -ge 1 ]; then
  notify_email "LVM/RAID 异常" "count=$ABN detail=$DETAIL host=$(hostname_short)" || true
fi
exit $SEV