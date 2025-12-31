# 脚本名称：net_check_dns_resolution.sh
# 用途：检查 DNS 解析可用性与延迟，异常时告警
# 依赖：bash、dig 或 getent hosts
# 权限：无需 root
# 参数：
#   --json               以 JSON 格式输出最差解析耗时
#   --names a,b,c        覆盖测试域名列表（逗号分隔）
# 环境变量：
#   DNS_TEST_NAMES="example.com,www.google.com"
# 退出码：0 正常；1 警告（耗时较大/部分失败）；2 严重（全部失败）；3 依赖缺失

set -u
. "$(dirname "$0")/../lib/common.sh"
load_env

JSON=0; NAMES=${DNS_TEST_NAMES:-example.com}
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
    --names) NAMES="$2"; shift ;;
  esac; shift || true
done

WORST_MS=0; FAILS=0; TOTAL=0
IFS=',' read -r -a arr <<< "$NAMES"
for n in "${arr[@]}"; do
  TOTAL=$((TOTAL+1))
  if command -v dig >/dev/null 2>&1; then
    ms=$(dig +stats +time=2 "$n" 2>/dev/null | awk '/Query time:/ {print $3}')
    if [ -z "$ms" ]; then FAILS=$((FAILS+1)); continue; fi
  else
    start=$(date +%s%3N)
    getent hosts "$n" >/dev/null 2>&1 || { FAILS=$((FAILS+1)); continue; }
    end=$(date +%s%3N); ms=$((end-start))
  fi
  [ "$ms" -gt "$WORST_MS" ] && WORST_MS=$ms
done

SEV=0
if [ "$FAILS" -ge "$TOTAL" ]; then SEV=2
elif [ "$FAILS" -gt 0 ] || [ "$WORST_MS" -ge 2000 ]; then SEV=1
else SEV=0; fi

if [ "$JSON" -eq 1 ]; then
  print_json dns worst_latency_ms "$WORST_MS" 2000 "$SEV"
else
  print_human dns worst_latency_ms "$WORST_MS" 2000 "$SEV"; echo "fails=$FAILS total=$TOTAL"
fi

if [ $SEV -ge 1 ]; then
  notify_email "DNS 解析异常" "worst_ms=$WORST_MS fails=$FAILS/$TOTAL host=$(hostname_short)" || true
fi
exit $SEV