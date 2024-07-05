#! /bin/bash
Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Green_font_prefix}[注意]${Font_color_suffix}"

function check_sys() {
    if [[ -f /etc/redhat-release ]]; then
        release="centos"
    elif cat /etc/issue | grep -q -E -i "debian"; then
        release="debian"
    elif cat /etc/issue | grep -q -E -i "ubuntu"; then
        release="ubuntu"
    elif cat /proc/version | grep -q -E -i "debian"; then
        release="debian"
    elif cat /proc/version | grep -q -E -i "ubuntu"; then
        release="ubuntu"
    elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
        release="centos"
    fi
    bit=$(uname -m)
    if test "$bit" != "x86_64"; then
        bit='arm64'
    else
        bit="amd64"
    fi
}

function Installation_dependency() {
    if [[ ${release} == "centos" ]]; then
        yum install -y wget lsof curl iptables
    else
        apt-get install -y wget lsof curl iptables
    fi
    if ! type docker >/dev/null 2>&1; then
        dpkg -i /root/docker/containerd.io_1.4.6-1_amd64.deb
        dpkg -i /root/docker/docker-ce-cli_20.10.7~3-0~debian-bullseye_amd64.deb
        dpkg -i /root/docker/docker-ce_20.10.7~3-0~debian-bullseye_amd64.deb
        systemctl start docker
        if [[ $? -ne 0 ]]; then
            echo -e "${Error} Docker服务启动失败，请检查日志信息。"
            sudo journalctl -xe
            exit 1
        fi
        systemctl enable docker
    fi
}

function check_root() {
    [[ $EUID != 0 ]] && echo -e "${Error} 当前非ROOT账号(或没有ROOT权限)，无法继续操作，请更换ROOT账号或使用 ${Green_background_prefix}sudo su${Font_color_suffix} 命令获取临时ROOT权限（执行后可能会提示输入当前账号的密码）。" && exit 1
}

function install() {
    check_sys
    Installation_dependency
    if [ -f /etc/xdzz/xd.mv.db ]; then
        docker stop xiandan || true
        echo '已存在数据库，先帮你把数据备份至/etc/xdzz/back.xd.mv.db'
        cp -f /etc/xdzz/xd.mv.db /etc/xdzz/back.xd.mv.db
    else
        wget -P /etc/xdzz http://sh.alhttdw.cn/xiandan/xd.mv.db
        wget -P /etc/xdzz http://sh.alhttdw.cn/xiandan/xd.trace.db
    fi
    read_port
}

function install_bot() {
    check_sys
    Installation_dependency
    rm -rf /etc/xdzz/bot_config
    mkdir /etc/xdzz/bot_config
    echo -e "{}" > /etc/xdzz/bot_config/db.json
    echo -e "${Green_font_prefix}请输入访问面板地址"
    echo -e "${Green_font_prefix}-----------------------------------"
    read -p "请输入(默认：http://127.0.0.1:2080): " url
    echo -e "${Green_font_prefix}请输入BOT_TOKEN"
    echo -e "${Green_font_prefix}-----------------------------------"
    read -p "请输入(自行联系@BotFather获取): " botToken
    echo -e "${Green_font_prefix}请输入闲蛋ApiToken"
    echo -e "${Green_font_prefix}-----------------------------------"
    read -p "请输入(请前往面板系统设置页查看): " apiToken
    if [[ ! -n $url ]]; then
        url="http://127.0.0.1:2080"
    fi
    if [[ ! -n $botToken ]]; then
        echo -e "${Green_font_prefix}botToken没输入"
        exit 0
    fi
    if [[ ! -n $apiToken ]]; then
        echo -e "${Green_font_prefix}apiToken没输入"
        exit 0
    fi
    echo -e "{" > /etc/xdzz/bot_config/domain.json
    echo -e "\t\"url\": \"${url}\"," >> /etc/xdzz/bot_config/domain.json
    echo -e "\t\"botToken\": \"${botToken}\"," >> /etc/xdzz/bot_config/domain.json
    echo -e "\t\"apiToken\": \"${apiToken}\"" >> /etc/xdzz/bot_config/domain.json
    echo -e "}" >> /etc/xdzz/bot_config/domain.json
    cat /etc/xdzz/bot_config/domain.json
    update_do_bot
}

function update() {
    check_sys
    if [[ ! -n $port ]]; then
        portinfo=`docker port xiandan | head -1`
        if [[ ! -n "$portinfo" ]]; then
            read_port
            exit 0
        else
            port=${portinfo#*:}
            if [ -f /etc/xdzz/xd.mv.db ]; then
                docker stop xiandan || true
                echo '先帮你把数据备份至/etc/xdzz/back.xd.mv.db'
                cp -f /etc/xdzz/xd.mv.db /etc/xdzz/back.xd.mv.db
            fi
            update_do
        fi
    else
        if [ -f /etc/xdzz/xd.mv.db ]; then
            docker stop xiandan || true
            echo '先帮你把数据备份至/etc/xdzz/back.xd.mv.db'
            cp -f /etc/xdzz/xd.mv.db /etc/xdzz/back.xd.mv.db
        fi
        update_do
    fi
}

function update_bot() {
    update_do_bot
}

function checkArea() {
    echo -e "请选择面板机器所在区域（是否为国外环境）"
    echo "-----------------------------------"
    read -p "请输入(1：国外，2：国内, 默认：1): " isChina
    if [[ ! -n $isChina ]]; then
        dns=8.8.8.8
    fi
    if [[ $isChina == 2 ]]; then
        echo -e "您选择了国内环境，面板dns为：223.5.5.5"
        dns=223.5.5.5
    else
        echo -e "您选择了国外环境，面板dns为：8.8.8.8"
        dns=8.8.8.8
    fi
    echo $dns > /etc/xdzz/dns
}

function update_do() {
    dns=`cat /etc/xdzz/dns`
    if [[ ! -n $dns ]]; then
        checkArea
    fi
    if [ ! -f /etc/docker/daemon.json ]; then
        wget -P /etc/docker sh.alhttdw.cn/xiandan/daemon.json
    fi
    systemctl restart docker
    version=`docker -v`
    restartTask=`crontab -l | grep xiandan`
    if [ "${restartTask}X" == "X" ];then
        if ! type crontab >/dev/null 2>&1; then
            check_sys
            if [[ ${release} == "centos" ]]; then
                yum install -y vixie-cron
                yum install -y crontabs
            else
                apt-get install -y cron
            fi
            service cron start
        fi
        restartTime=3
        crontab -l > conf
        sed -i '/xiandan/d' conf
        echo "0 0 ${restartTime} * * docker restart xiandan" >> conf
        crontab conf
        rm -f conf
    fi
    if ! type docker >/dev/null 2>&1; then
        dpkg -i /root/docker/containerd.io_1.4.6-1_amd64.deb
        dpkg -i /root/docker/docker-ce-cli_20.10.7~3-0~debian-bullseye_amd64.deb
        dpkg -i /root/docker/docker-ce_20.10.7~3-0~debian-bullseye_amd64.deb
        systemctl start docker
        systemctl enable docker
    fi
    if [[ ! -n "$vNum" ]];then
        vNum='latest'
    fi
    docker rm -f xiandan || true
    echo "dns为${dns}"
    echo "平台架构为${bit}"
    if [[ ${bit} == "arm64" ]]; then
        docker load -i /root/docker_images/xiandan_release_latest.tar
        docker run --platform linux/${bit} --log-opt max-size=10m --dns=${dns} --log-driver json-file --restart=always --name=xiandan -v /etc/xdzz:/xiandan -p ${port}:8080 -d xiandan/release/arm:${vNum}
    else
        docker load -i /root/docker_images/xiandan_release_latest.tar
        docker run --platform linux/${bit} --log-opt max-size=10m --dns=${dns} --log-driver json-file --restart=always --name=xiandan -v /etc/xdzz:/xiandan -p ${port}:8080 -d docker.xdmb.xyz/xiandan/release:${vNum}
    fi
    echo -e "${Green_font_prefix}闲蛋面板已安装成功！请等待1-2分钟后访问面板入口。${Font_color_suffix}"
    echo -e "${Green_font_prefix}访问入口为 服务器IP:${port} ${Font_color_suffix}"
}

function update_do_bot() {
    check_sys
    docker rm -f xd-bot || true
    echo "平台架构为${bit}"
    if [[ ${bit} == "arm64" ]]; then
        docker load -i /root/docker_images/xiandan_bot_latest.tar
        docker run --platform linux/${bit} --name xd-bot --network host --restart=always -v /etc/xdzz/bot_config:/usr/src/app/bot_config -d xiandan/bot/arm:latest
    else
        docker load -i /root/docker_images/xiandan_bot_latest.tar
        docker run --platform linux/${bit} --name xd-bot --network host --restart=always -v /etc/xdzz/bot_config:/usr/src/app/bot_config -d docker.xdmb.xyz/xiandan/bot:latest
    fi
    exit 0
}

function uninstall() {
    read -p "确定卸载当前服务器上的闲蛋面板么？卸载后数据将无法找回。（Y:是）" isConfirmed
    if [[ $isConfirmed == 'Y' || $isConfirmed == 'y' ]]; then
        rm -rf /etc/xdzz
        docker rm -f xiandan || true
        echo -e "${Green_font_prefix}闲蛋已成功卸载${Font_color_suffix}"
    fi
}

function nodeuninstall() {
    arr=`ls /etc/systemd/system | grep xiandan | cut -d . -f 1`
    for i in $arr
    do
        echo "stop ${i}"
        systemctl stop $i
    done
    rm -rf /etc/systemd/system/xiandan*
    rm -rf /etc/xiandan
    echo -e "${Green_font_prefix}闲蛋节点已成功卸载，规则已删除，请将服务器从面板上删除！${Font_color_suffix}"
}

function uninstall_bot() {
    rm -rf /etc/xdzz/bot_config
    docker rm -f xd-bot || true
    echo -e "${Green_font_prefix}闲蛋BOT已成功卸载${Font_color_suffix}"
}

function start() {
    portinfo=`docker ps -a | grep xiandan`
    if [[ ! -n "$portinfo" ]]; then
        echo -e "${Green_font_prefix}面板未安装,请安装面板！${Font_color_suffix}"
    else
        docker start xiandan
        echo -e "${Green_font_prefix}已启动${Font_color_suffix}"
    fi
}

function start_bot() {
    portinfo=`docker ps -a | grep xd-bot`
    if [[ ! -n "$portinfo" ]]; then
        echo -e "${Green_font_prefix}BOT未安装,请安装！${Font_color_suffix}"
    else
        docker start xd-bot
        echo -e "${Green_font_prefix}已启动${Font_color_suffix}"
    fi
}

function stop() {
    portinfo=`docker ps -a | grep xiandan`
    if [[ ! -n "$portinfo" ]]; then
        echo -e "${Green_font_prefix}面板未安装,请安装面板！${Font_color_suffix}"
    else
        docker stop xiandan
        echo -e "${Green_font_prefix}已停止${Font_color_suffix}"
    fi
}

function stop_bot() {
    portinfo=`docker ps -a | grep xd-bot`
    if [[ ! -n "$portinfo" ]]; then
        echo -e "${Green_font_prefix}BOT未安装,请安装！${Font_color_suffix}"
    else
        docker stop xd-bot
        echo -e "${Green_font_prefix}已停止${Font_color_suffix}"
    fi
}

function restart() {
    portinfo=`docker ps -a | grep xiandan`
    if [[ ! -n "$portinfo" ]]; then
        echo -e "${Green_font_prefix}面板未安装,请安装面板！${Font_color_suffix}"
    else
        docker restart xiandan
        echo -e "${Green_font_prefix}已重启${Font_color_suffix}"
    fi
}

function restart_bot() {
    portinfo=`docker ps -a | grep xd-bot`
    if [[ ! -n "$portinfo" ]]; then
        echo -e "${Green_font_prefix}BOT未安装,请安装！${Font_color_suffix}"
    else
        docker restart xd-bot
        echo -e "${Green_font_prefix}已重启${Font_color_suffix}"
    fi
}

function restore() {
    rm -rf /etc/xdzz
    wget -P /etc/xdzz http://sh.alhttdw.cn/xiandan/xd.mv.db
    wget -P /etc/xdzz http://sh.alhttdw.cn/xiandan/xd.trace.db
    restart
}

function reset() {
    str=`docker ps | grep xiandan`
    if [[ ! -n "$str" ]]; then
        echo -e "${Green_font_prefix}面板未运行${Font_color_suffix}"
        exit 0
    fi
    bash <(wget --no-check-certificate -qO- 'http://sh.alhttdw.cn/xiandan/reset.sh')
    echo -e "${Green_font_prefix}超级管理员已重置为admin / admin${Font_color_suffix}"
}

function read_port() {
    echo -e "请输入面板映射端口（面板访问端口）"
    echo "-----------------------------------"
    read -p "请输入(1-65535, 默认：80): " port
    if [[ ! -n $port ]]; then
        port=80
    fi
    if [ "$port" -gt 0 ] 2>/dev/null; then
        if [[ $port -lt 0 || $port -gt 65535 ]]; then
            echo -e "端口号不正确"
            read_port
            exit 0
        fi
        isUsed=`lsof -i:${port}`
        if [ -n "$isUsed" ]; then
            echo -e "端口被占用"
            read_port
            exit 0
        fi
        update
    else
        read_port
        exit 0
    fi
}

function rollback() {
    echo -e "请输入特定版本号"
    echo "-----------------------------------"
    read -p "请输入一个可用的版本号: " vNum
    update
}

function autoRestart() {
    if ! type crontab >/dev/null 2>&1; then
        echo '安装crontab'
        check_sys
        if [[ ${release} == "centos" ]]; then
            yum install -y vixie-cron
            yum install -y crontabs
        else
            apt-get install -y cron
        fi
        service cron start
    fi
    read -p "请输入(0-23, 默认：3): " restartTime
    if [[ ! -n $restartTime ]]; then
        restartTime=3
    fi
    if [[ $restartTime -lt 0 || $restartTime -gt 23 ]]; then
        echo -e "请输入正确数字"
        exit 0
    fi
    crontab -l > conf
    sed -i '/xiandan/d' conf
    echo "0 0 ${restartTime} * * docker restart xiandan" >> conf
    crontab conf
    rm -f conf
    echo -e "定时任务设置成功！每天${restartTime}点重启面板"
}

function auto() {
    check_root
    echo && echo -e "${Green_font_prefix}       闲蛋面板 一键脚本
   ${Green_font_prefix} ----------- Noob_Cfy -----------
   ${Green_font_prefix}1. 安装 闲蛋面板
   ${Green_font_prefix}2. 更新 闲蛋面板
   ${Green_font_prefix}3. 卸载 闲蛋面板
  ————————————
   ${Green_font_prefix}4. 启动 闲蛋面板
   ${Green_font_prefix}5. 停止 闲蛋面板
   ${Green_font_prefix}6. 重启 闲蛋面板
  ————————————
   ${Green_font_prefix}7. 数据库还原
   ${Green_font_prefix}8. 管理员用户名密码重置
   ${Green_font_prefix}9. 安装特定版本
   ${Green_font_prefix}10. 设置自动重启
  ————————————
   ${Green_font_prefix}11. 安装 TG_BOT
   ${Green_font_prefix}12. 更新 TG_BOT
   ${Green_font_prefix}13. 卸载 TG_BOT
  ————————————
   ${Green_font_prefix}14. 启动 TG_BOT
   ${Green_font_prefix}15. 停止 TG_BOT
   ${Green_font_prefix}16. 重启 TG_BOT
  ————————————
   ${Green_font_prefix}17. 节点规则清除
   ${Green_font_prefix}0. 退出脚本
  ———————————— ${Font_color_suffix}" && echo
    read -e -p " 请输入数字 [0-17]:" num
    case "$num" in
        1)
            install
            ;;
        2)
            update
            ;;
        3)
            uninstall
            ;;
        4)
            start
            ;;
        5)
            stop
            ;;
        6)
            restart
            ;;
        7)
            restore
            ;;
        8)
            reset
            ;;
        9)
            rollback
            ;;
        10)
            autoRestart
            ;;
        11)
            install_bot
            ;;
        12)
            update_bot
            ;;
        13)
            uninstall_bot
            ;;
        14)
            start_bot
            ;;
        15)
            stop_bot
            ;;
        16)
            restart_bot
            ;;
        17)
            nodeuninstall
            ;;
        0)
            exit 0
            ;;
        *)
            echo "请输入正确数字 [0-17]"
            ;;
    esac
}

if [ $# -gt 0 ] ; then
    if [ $1 == "install" ]; then
        install
    elif [ $1 == "start" ]; then
        start
    elif [ $1 == "stop" ]; then
        stop
    elif [ $1 == "update" ]; then
        update
    elif [ $1 == "uninstall" ]; then
        uninstall
    fi
else
    auto
fi
