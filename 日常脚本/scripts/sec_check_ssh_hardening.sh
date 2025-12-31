# 脚本名称：sec_check_ssh_hardening.sh
# 用途：检查 sshd 配置是否符合安全基线（禁止 root 登录、禁用密码登录等）
# 依赖：bash、grep；可选：sshd -t
# 权限：建议 root
# 参数：
#   --json                   以 JSON 输出违反项数量
# 环境变量：无
# 退出码：0 合规；1 违反；2 严重（多项违反或配置错误）；3 依赖缺失

set -u
. "$(dirname "$0")/../lib/common.sh"
load_env

CONF=/etc/ssh/sshd_config
[ -r "$CONF" ] || exit_missing_dep sshd_config

JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
  esac; shift || true
done

VIOL=0; DETAIL=""
grep -Ei '^\s*PermitRootLogin\s+no' "$CONF" >/dev/null 2>&1 || { VIOL=$((VIOL+1)); DETAIL="$DETAIL PermitRootLogin!=no"; }
grep -Ei '^\s*PasswordAuthentication\s+no' "$CONF" >/dev/null 2>&1 || { VIOL=$((VIOL+1)); DETAIL="$DETAIL PasswordAuthentication!=no"; }
grep -Ei '^\s*X11Forwarding\s+no' "$CONF" >/dev/null 2>&1 || { VIOL=$((VIOL+1)); DETAIL="$DETAIL X11Forwarding!=no"; }

if command -v sshd >/dev/null 2>&1; then
  sshd -t 2>/dev/null || { VIOL=$((VIOL+1)); DETAIL="$DETAIL invalid_config"; }
fi

SEV=0
if [ "$VIOL" -ge 3 ]; then SEV=2
elif [ "$VIOL" -gt 0 ]; then SEV=1
else SEV=0; fi

if [ "$JSON" -eq 1 ]; then
  print_json ssh hardening_violations "$VIOL" 0 "$SEV"
else
  print_human ssh hardening_violations "$VIOL" 0 "$SEV"; echo "detail:$DETAIL"
fi

if [ $SEV -ge 1 ]; then
  notify_email "SSH 配置不合规" "violations=$VIOL detail=$DETAIL host=$(hostname_short)" || true
fi
exit $SEV