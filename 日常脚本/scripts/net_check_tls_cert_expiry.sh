# 脚本名称：net_check_tls_cert_expiry.sh
# 用途：检查远端 TLS 证书到期时间，临近过期告警
# 依赖：bash、openssl
# 权限：无需 root
# 参数：
#   --json                 以 JSON 格式输出最短剩余天数
#   --targets host:port,... 覆盖检查目标列表
#   --warn N               覆盖警告阈值（剩余天数）
#   --crit N               覆盖严重阈值（剩余天数）
# 环境变量：
#   TLS_CHECK_TARGETS="example.com:443" TLS_EXPIRY_WARN_DAYS=21 TLS_EXPIRY_CRIT_DAYS=7
# 退出码：0 正常；1 警告；2 严重；3 依赖缺失

set -u
. "$(dirname "$0")/../lib/common.sh"
load_env

JSON=0; TARGETS=${TLS_CHECK_TARGETS:-example.com:443}; WARN=${TLS_EXPIRY_WARN_DAYS:-21}; CRIT=${TLS_EXPIRY_CRIT_DAYS:-7}
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
    --targets) TARGETS="$2"; shift ;;
    --warn) WARN="$2"; shift ;;
    --crit) CRIT="$2"; shift ;;
  esac; shift || true
done

command -v openssl >/dev/null 2>&1 || exit_missing_dep openssl

MIN_DAYS=99999; WORST=""
IFS=',' read -r -a arr <<< "$TARGETS"
for t in "${arr[@]}"; do
  host=$(echo "$t" | awk -F ':' '{print $1}')
  port=$(echo "$t" | awk -F ':' '{print $2}')
  end=$(echo | openssl s_client -servername "$host" -connect "$host:${port:-443}" 2>/dev/null | openssl x509 -noout -enddate | awk -F '=' '{print $2}')
  if [ -z "$end" ]; then continue; fi
  end_ts=$(date -d "$end" +%s 2>/dev/null)
  now_ts=$(date +%s)
  days=$(( (end_ts-now_ts)/86400 ))
  if [ "$days" -lt "$MIN_DAYS" ]; then MIN_DAYS=$days; WORST="$t"; fi
done

SEV=0
if [ "$MIN_DAYS" -le "$CRIT" ]; then SEV=2
elif [ "$MIN_DAYS" -le "$WARN" ]; then SEV=1
else SEV=0; fi

if [ "$JSON" -eq 1 ]; then
  print_json tls min_days_left "$MIN_DAYS" "$WARN" "$SEV"
else
  print_human tls min_days_left "$MIN_DAYS" "$WARN" "$SEV"; echo "worst=$WORST"
fi

if [ $SEV -ge 1 ]; then
  notify_email "TLS 证书即将过期" "min_days=$MIN_DAYS worst=$WORST warn=$WARN crit=$CRIT host=$(hostname_short)" || true
fi
exit $SEV