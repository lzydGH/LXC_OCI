#!/bin/bash

# 检查参数数量
if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    echo "用法: $0 <容器ID> [y/n]"
    exit 1
fi

# 定义配置文件路径
CONF_FILE="/etc/pve/lxc/$1.conf"

# 检查配置文件是否存在
if [ ! -f "$CONF_FILE" ]; then
    echo "错误：配置文件 $CONF_FILE 不存在！"
    exit 1
fi

# 检测/mnt/DSM/下的.pat文件
PAT_FILES=(/mnt/DSM/*.pat)
# 过滤掉不匹配
PAT_COUNT=0
for file in "${PAT_FILES[@]}"; do
    if [ -f "$file" ]; then
        ((PAT_COUNT++))
        PAT_PATH="$file"
    fi
done

# 处理.pat文件数量
if [ $PAT_COUNT -eq 0 ]; then
    echo "错误：/mnt/DSM/目录下未找到.pat文件！"
    exit 1
elif [ $PAT_COUNT -gt 1 ]; then
    echo "错误：/mnt/DSM/目录下找到多个.pat文件，请删除多余文件后再执行脚本！"
    exit 1
fi

# 执行sed替换操作
sed -i 's/unprivileged: 1/unprivileged: 0/' "$CONF_FILE"

# 处理确认参数
if [ $# -eq 2 ]; then
    CONFIRM=$2
else
    # 交互式询问
    read -p "是否确认添加配置信息到 $CONF_FILE？(y/n) " -n 1 -r
    echo
    CONFIRM=$REPLY
fi

# 判断是否确认
if [[ $CONFIRM =~ ^[Yy]$ ]]; then
    # 追加配置信息到文件（使用自动检测的PAT_PATH）
    cat << EOF >> "$CONF_FILE"
dev0: /dev/kvm
dev1: /dev/net/tun
dev2: /dev/vhost-net
lxc.mount.entry: /dev/shm dev/shm none bind,create=dir 0 0
lxc.mount.entry: $PAT_PATH boot.pat none bind,create=file 0
lxc.apparmor.profile: unconfined
lxc.cap.drop: 
lxc.cgroup2.devices.allow: c *:* rwm
lxc.net.0.type: macvlan
lxc.net.0.link: vmbr0
lxc.net.0.flags: up
lxc.net.0.macvlan.mode: bridge
EOF
    echo "配置信息已添加到 $CONF_FILE"
elif [[ $CONFIRM =~ ^[Nn]$ ]]; then
    echo "用户取消操作，退出执行"
    exit 0
else
    echo "错误：无效的确认参数，请使用 y 或 n"
    exit 1
fi
