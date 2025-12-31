# 脚本名称：sec_check_user_accounts.sh
# 用途：检查本地用户账户与 sudoers 配置的异常项
# 依赖：bash、awk、getent；可选：chage
# 权限：建议 root
# 参数：
#   --json                   以 JSON 输出异常项计数
#   --expected u1,u2         覆盖期望普通用户列表
# 环境变量：
#   EXPECTED_USERS=""
# 退出码：0 正常；1 有异常；2 严重（大量异常或过期账户）；3 依赖缺失

set -u
. "$(dirname "$0")/../lib/common.sh"
load_env

JSON=0; EXPECTED=${EXPECTED_USERS:-}
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
    --expected) EXPECTED="$2"; shift ;;
  esac; shift || true
done

require_cmd getent || exit_missing_dep getent

# 统计 uid>=1000 的普通用户
USERS=$(getent passwd | awk -F ':' '$3>=1000 {print $1}' | sort)
ABN=0; DETAIL=""
for u in $USERS; do
  shell=$(getent passwd "$u" | awk -F ':' '{print $NF}')
  [ "$shell" = "/usr/sbin/nologin" ] && continue
  if [ -n "$EXPECTED" ]; then
    echo "$EXPECTED" | tr ',' '\n' | grep -wq "$u" || { ABN=$((ABN+1)); DETAIL="$DETAIL unexpected_user:$u"; }
  fi
  if command -v chage >/dev/null 2>&1; then
    exp=$(chage -l "$u" 2>/dev/null | awk -F ': ' '/Account expires/ {print $2}')
    [ "$exp" = "expired" ] && { ABN=$((ABN+1)); DETAIL="$DETAIL expired:$u"; }
  fi
done

# 检查 sudoers 中的异常授权（简单检查）
if [ -r /etc/sudoers ]; then
  SUD=$(grep -E '^[^#].*ALL=\(ALL\) ALL' /etc/sudoers 2>/dev/null | wc -l)
  [ "$SUD" -gt 0 ] && { ABN=$((ABN+SUD)); DETAIL="$DETAIL sudoers_unrestricted:$SUD"; }
fi

SEV=0
if [ "$ABN" -ge 10 ]; then SEV=2
elif [ "$ABN" -gt 0 ]; then SEV=1
else SEV=0; fi

if [ "$JSON" -eq 1 ]; then
  print_json accounts anomalies "$ABN" 0 "$SEV"
else
  print_human accounts anomalies "$ABN" 0 "$SEV"; echo "detail:$DETAIL"
fi

if [ $SEV -ge 1 ]; then
  notify_email "用户账户异常" "count=$ABN detail=$DETAIL host=$(hostname_short)" || true
fi
exit $SEV