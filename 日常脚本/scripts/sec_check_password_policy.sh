# 脚本名称：sec_check_password_policy.sh
# 用途：检查 PAM 密码策略是否启用（长度/复杂度），不合规告警
# 依赖：bash、grep
# 权限：建议 root
# 参数：
#   --json                   以 JSON 输出违反项数量
# 环境变量：无
# 退出码：0 合规；1 违反；2 严重（完全未启用或明显弱策略）；3 依赖缺失

set -u
. "$(dirname "$0")/../lib/common.sh"
load_env

JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
  esac; shift || true
done

CONF_COMMON=/etc/pam.d/common-password
CONF_SYSTEM=/etc/pam.d/system-auth

FILE=""
if [ -r "$CONF_COMMON" ]; then FILE="$CONF_COMMON"; elif [ -r "$CONF_SYSTEM" ]; then FILE="$CONF_SYSTEM"; else exit_missing_dep pam_config; fi

VIOL=0; DETAIL=""
grep -E 'pam_pwquality.so|pam_cracklib.so' "$FILE" >/dev/null 2>&1 || { VIOL=$((VIOL+1)); DETAIL="$DETAIL no_pwquality"; }
grep -E 'minlen=([1-9][0-9])' "$FILE" >/dev/null 2>&1 || { VIOL=$((VIOL+1)); DETAIL="$DETAIL minlen<10"; }
grep -E 'retry=([2-9])' "$FILE" >/dev/null 2>&1 || true

SEV=0
if [ "$VIOL" -ge 2 ]; then SEV=2
elif [ "$VIOL" -gt 0 ]; then SEV=1
else SEV=0; fi

if [ "$JSON" -eq 1 ]; then
  print_json pam policy_violations "$VIOL" 0 "$SEV"
else
  print_human pam policy_violations "$VIOL" 0 "$SEV"; echo "detail:$DETAIL file=$FILE"
fi

if [ $SEV -ge 1 ]; then
  notify_email "密码策略不合规" "violations=$VIOL detail=$DETAIL file=$FILE host=$(hostname_short)" || true
fi
exit $SEV