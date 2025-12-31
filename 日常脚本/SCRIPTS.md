# 服务器常用脚本清单（50个）

## 系统与资源
1. `scripts/sys_check_cpu_load.sh`：检查系统负载与 CPU 使用率
2. `scripts/sys_check_cpu_steal.sh`：检测 CPU steal time（虚拟化争用）
3. `scripts/sys_check_memory_usage.sh`：内存占用百分比与阈值告警
4. `scripts/sys_check_swap_activity.sh`：Swap 使用百分比与速率摘要
5. `scripts/sys_check_disk_usage.sh`：各挂载点容量与 inode 使用率
6. `scripts/sys_check_disk_iowait.sh`：CPU I/O 等待比率（iowait）
7. `scripts/sys_check_fs_errors.sh`：文件系统错误（dmesg/journal）
8. `scripts/sys_check_inodes_exhaustion.sh`：inode 使用率（汇总最大值）
9. `scripts/sys_check_sensors_temp.sh`：硬件温度（lm-sensors）
10. `scripts/sys_check_time_sync.sh`：时间同步状态与漂移
11. `scripts/sys_check_entropy_pool.sh`：系统熵池可用性
12. `scripts/sys_check_oom_events.sh`：OOM Kill 事件扫描

## 网络与端口
13. `scripts/net_check_network_latency.sh`：ping 延迟与丢包率
14. `scripts/net_check_dns_resolution.sh`：DNS 解析可用性/延迟
15. `scripts/net_check_required_ports_listen.sh`：必需端口监听状态
16. `scripts/net_check_unexpected_open_ports.sh`：异常开放端口检测
17. `scripts/net_check_firewall_rules.sh`：防火墙规则与默认策略
18. `scripts/net_check_tls_cert_expiry.sh`：TLS 证书到期检查
19. `scripts/net_check_bandwidth_usage.sh`：网卡瞬时带宽使用（bytes/s）
20. `scripts/net_check_route_table_changes.sh`：路由表与基线差异

## 进程与服务
21. `scripts/svc_check_systemd_services.sh`：关键服务 active/running 状态
22. `scripts/svc_check_process_flapping.sh`：服务短时间频繁重启（抖动）
23. `scripts/svc_check_zombie_processes.sh`：僵尸进程数量与父进程
24. `scripts/svc_check_core_dumps.sh`：核心转储文件检查
25. `scripts/svc_check_fd_usage.sh`：文件句柄使用率
26. `scripts/svc_check_cron_failures.sh`：定时任务失败统计

## 日志与错误
27. `scripts/log_monitor_syslog_errors.sh`：系统日志 ERROR/CRIT 速率
28. `scripts/log_monitor_app_log_patterns.sh`：应用日志错误模式匹配
29. `scripts/log_check_audit_violations.sh`：审计关键事件与违规
30. `scripts/log_check_fail2ban_activity.sh`：Fail2ban 状态与封禁计数
31. `scripts/log_check_auth_failures.sh`：登录失败事件统计

## 安全与合规
32. `scripts/sec_check_user_accounts.sh`：本地用户与 sudoers 异常
33. `scripts/sec_check_world_writable_files.sh`：世界可写文件/目录
34. `scripts/sec_check_suid_sgid_binaries.sh`：SUID/SGID 可执行
35. `scripts/sec_check_open_ports_baseline.sh`：开放端口基线比对
36. `scripts/sec_check_rootkit_signatures.sh`：rootkit 可疑特征检查
37. `scripts/sec_check_ssh_hardening.sh`：SSH 配置安全基线核查
38. `scripts/sec_check_password_policy.sh`：PAM 密码策略核查
39. `scripts/sec_check_file_integrity.sh`：文件完整性（AIDE）

## 存储与备份
40. `scripts/stg_check_lvm_raid_health.sh`：LVM/mdadm RAID 健康
41. `scripts/stg_check_backup_status.sh`：备份标记时间与过期检查
42. `scripts/stg_check_snapshot_age.sh`：LVM/ZFS 快照年龄与数量
43. `scripts/stg_check_nfs_mount_health.sh`：NFS 挂载可用性

## 数据库与中间件
44. `scripts/db_check_mysql_health.sh`：MySQL 连接数与复制延迟
45. `scripts/db_check_postgres_health.sh`：PostgreSQL 连接数检查
46. `scripts/db_check_redis_health.sh`：Redis 内存与驱逐率
47. `scripts/web_check_http_health.sh`：HTTP 状态码与响应时间

## 容器与虚拟化
48. `scripts/ctr_check_docker_container_health.sh`：容器健康与重启次数
49. `scripts/k8s_check_node_status.sh`：K8s 节点就绪状态
50. `scripts/sys_check_cgroup_psi.sh`：cgroup PSI 压力指标

---

## 使用规范
- 通用参数：`--json` 输出 JSON；脚本内根据需要支持 `--warn/--crit/--targets/--urls/--ports` 等。
- 退出码约定：`0` 正常、`1` 警告、`2` 严重、`3` 依赖缺失。
- 统一输出：人类可读一行摘要 + 可选 JSON（字段包含 `host`、`ts`、`component`、`metric`、`value`、`threshold`、`severity`）。

## 配置说明
- 全局阈值与目标在 `config/default.env` 中设置；环境变量可覆盖。
- 邮件告警使用 `alerts/send_mail.py`（配置 `SMTP_*` 与 `MAIL_TO`）。

## 示例
- `./scripts/check_cpu_load.sh --json`
- `PING_TARGETS="1.1.1.1,8.8.8.8" ./scripts/check_network_latency.sh --json`
- `REQUIRED_SERVICES="sshd,nginx" ./scripts/check_systemd_services.sh`