#!/bin/bash

# 检查realm是否已安装
if [ -f "/root/realm/realm" ]; then
    echo "检测到realm已安装。"
    realm_status="已安装"
    realm_status_color="\033[0;32m" # 绿色
else
    echo "realm未安装。"
    realm_status="未安装"
    realm_status_color="\033[0;31m" # 红色
fi

# 显示菜单的函数
show_menu() {
    clear
    echo "欢迎使用realm一键转发脚本"
    echo "================="
    echo "1. 部署环境"
    echo "2. 添加转发"
    echo "3. 删除转发"
    echo "4. 启动服务"
    echo "================="
    echo -e "realm 状态：${realm_status_color}${realm_status}\033[0m"
}


# 部署环境的函数
deploy_realm() {
    mkdir -p /root/realm
    cd /root/realm
    wget -O realm.tar.gz https://github.com/zhboner/realm/releases/download/v2.5.3/realm-x86_64-unknown-linux-gnu.tar.gz
    tar -xvf realm.tar.gz
    chmod +x realm
    # 创建服务文件
    echo "[Unit]
Description=realm
After=network-online.target
Wants=network-online.target systemd-networkd-wait-online.service

[Service]
Type=simple
User=root
Restart=on-failure
RestartSec=5s
DynamicUser=true
WorkingDirectory=/root/realm
ExecStart=/root/realm/realm -c /root/realm/config.toml

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/realm.service
    systemctl daemon-reload
    # 更新realm状态变量
    realm_status="已安装"
    realm_status_color="\033[0;32m" # 绿色
    echo "部署完成。"
}

# 添加转发规则
add_forward() {
    while true; do
        read -p "请输入IP: " ip
        read -p "请输入端口: " port
        # 追加到config.toml文件
        echo "[[endpoints]]
listen = \"0.0.0.0:$port\"
remote = \"$ip:$port\"" >> /root/realm/config.toml
        
        read -p "是否继续添加(Y/N)? " answer
        if [[ $answer != "Y" && $answer != "y" ]]; then
            break
        fi
    done
}

# 启动服务
start_service() {
    systemctl daemon-reload
    systemctl restart realm
    systemctl enable realm
    echo "realm服务已启动并设置为开机自启。"
}

# 主循环
while true; do
    show_menu
    read -p "请选择一个选项: " choice
    case $choice in
        1)
            deploy_realm
            ;;
        2)
            add_forward
            ;;
        3)
            echo "此功能尚未实现。"
            ;;
        4)
            start_service
            ;;
        *)
            echo "无效选项: $choice"
            ;;
    esac
    read -p "按任意键继续..." key
done
