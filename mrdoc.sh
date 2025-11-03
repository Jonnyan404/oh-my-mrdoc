#!/bin/bash
# DATE: 2021-4-15 11:55:47
# Author: create by jonnyan404
# Blog:https://www.mrdoc.fun
# Description:This script is auto install mrdoc project
# Version:1.5.0
# Modified: 2025-11-03

# 检查root权限
if [[ $EUID -ne 0 ]]; then
    echo -e "\033[31m此脚本需要root权限运行\033[0m"
    exit 1
fi

SYSTEMCTL_CMD=$(command -v systemctl 2>/dev/null)
WORK_PATH=$(cd "$(dirname "$0")";pwd)
#SERVICE_CMD=$(command -v service 2>/dev/null)
SOFTWARE_UPDATED=0
SCR_VERSION="2022.01.14"
#######color code########
RED="31m"      # Error message
GREEN="32m"    # Success message
YELLOW="33m"   # Warning message
BLUE="36m"     # Info message


colorEcho(){
    COLOR=$1
    echo -e "\033[${COLOR}${*:2}\033[0m"
}

installdepend(){
    if [[ -n $(command -v apt-get) ]];then
        if [[ $SOFTWARE_UPDATED -eq 0 ]]; then
            colorEcho ${BLUE} "Debian/Ubuntu Updating software repo"
            if ! apt-get update; then
                colorEcho ${RED} "软件源更新失败"
                return 1
            fi
            SOFTWARE_UPDATED=1
        fi
        if ! apt-get -y install git python3 python3-dev python3-pip gcc python3-wheel python3-setuptools python3-venv libldap2-dev libsasl2-dev libmariadb-dev; then
            colorEcho ${RED} "依赖安装失败"
            return 1
        fi
    elif [[ -n $(command -v yum) ]]; then
        if [[ $SOFTWARE_UPDATED -eq 0 ]]; then
            colorEcho ${BLUE} "Centos Updating software repo"
            if ! yum -q makecache; then
                colorEcho ${RED} "软件源更新失败"
                return 1
            fi
            SOFTWARE_UPDATED=1
        fi
        if ! yum -y install epel-release git python3 python3-devel python3-pip gcc openldap openldap-devel openssl-devel; then
            colorEcho ${RED} "基础依赖安装失败"
            return 1
        fi
        # 修复拼写错误：insatll -> install
        if ! yum -y install mariadb-devel; then
            colorEcho ${YELLOW} "mariadb-devel 安装失败，继续尝试其他依赖"
        fi
        if ! yum -y install mysql-devel; then
            colorEcho ${YELLOW} "mysql-devel 安装失败，继续尝试其他依赖"
        fi
        
        # 检查 SQLite 是否已安装
        if ! command -v sqlite3 &> /dev/null; then
            colorEcho ${YELLOW} "SQLite3 not found, installing..."
            if ! yum -y install sqlite sqlite-devel; then
                colorEcho ${RED} "SQLite3 安装失败"
                return 1
            fi
        fi
        
        # 检查 SQLite 版本
        sqliteversion=$(sqlite3 -version 2>/dev/null | awk '{print $1}')
        if [[ -z "$sqliteversion" ]]; then
            colorEcho ${RED} "无法获取SQLite版本"
            return 1
        fi
        
        function version_ge() { test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" == "$1"; }
        if version_ge $sqliteversion "3.9.0"; then
            colorEcho ${BLUE} "Sqlite3 Version ${sqliteversion} Support!"
        else
            colorEcho ${YELLOW} "Sqlite3 Version ${sqliteversion} Not Support,Install New Version..."
            
            # 检查源码包是否存在
            if [[ ! -f "$WORK_PATH/sqlite-autoconf-3340000.tar.gz" ]]; then
                colorEcho ${RED} "SQLite源码包不存在: $WORK_PATH/sqlite-autoconf-3340000.tar.gz"
                colorEcho ${YELLOW} "请下载SQLite源码包或使用系统默认版本"
                return 1
            fi
            
            # 检查编译依赖
            if ! command -v gcc &> /dev/null || ! command -v make &> /dev/null; then
                colorEcho ${RED} "缺少编译工具 gcc 或 make"
                if ! yum -y install gcc make; then
                    colorEcho ${RED} "编译工具安装失败"
                    return 1
                fi
            fi
            
            # 解压和编译 SQLite
            if ! tar -zxvf "$WORK_PATH/sqlite-autoconf-3340000.tar.gz" -C /tmp; then
                colorEcho ${RED} "SQLite源码包解压失败"
                return 1
            fi
            
            cd /tmp/sqlite-autoconf-3340000 || {
                colorEcho ${RED} "进入SQLite源码目录失败"
                return 1
            }
            
            if ! ./configure --prefix=/usr/local; then
                colorEcho ${RED} "SQLite configure 失败"
                return 1
            fi
            
            if ! make; then
                colorEcho ${RED} "SQLite make 失败"
                return 1
            fi
            
            if ! make install; then
                colorEcho ${RED} "SQLite make install 失败"
                return 1
            fi
            
            # 备份原有版本并创建链接
            if [[ -f /usr/bin/sqlite3 ]]; then
                mv /usr/bin/sqlite3 /usr/bin/sqlite3_backup
            fi
            ln -sf /usr/local/bin/sqlite3 /usr/bin/sqlite3
            echo "/usr/local/lib" > /etc/ld.so.conf.d/sqlite3.conf
            ldconfig
            
            # 验证安装
            new_version=$(sqlite3 -version 2>/dev/null | awk '{print $1}')
            if [[ -n "$new_version" ]]; then
                colorEcho ${GREEN} "SQLite 更新成功，新版本: $new_version"
            else
                colorEcho ${RED} "SQLite 更新失败"
                return 1
            fi
        fi    
    else
        colorEcho ${RED} "The system package manager tool isn't APT or YUM, please install depend manually."
        return 1
    fi
    return 0
}

installmrdoc(){
    MRDOCDIR=/opt/jonnyan404
    USER="admin"
    MM=$(cat /proc/sys/kernel/random/uuid| cut -f1 -d "-")

    if ! mkdir -p ${MRDOCDIR}; then
        colorEcho ${RED} "创建目录 ${MRDOCDIR} 失败"
        return 1
    fi
    
    touch ${MRDOCDIR}/"${GIT_DIR}"pwdinfo.log
    
    if ! cd ${MRDOCDIR}; then
        colorEcho ${RED} "进入目录 ${MRDOCDIR} 失败"
        return 1
    fi
    
    if ! git clone ${GIT_LINK}; then
        colorEcho ${RED} "克隆代码仓库失败"
        return 1
    fi
    
    if ! pip3 install uwsgi; then
        colorEcho ${RED} "安装 uwsgi 失败"
        return 1
    fi
    
    if ! python3 -m venv ${MRDOCDIR}/"${GIT_DIR}"_env; then
        colorEcho ${RED} "创建虚拟环境失败"
        return 1
    fi
    
    source ${MRDOCDIR}/"${GIT_DIR}"_env/bin/activate \
    && pip3 install --upgrade pip \
    && cd ${MRDOCDIR}/"${GIT_DIR}" \
    && pip3 install -r requirements.txt \
    && python3 manage.py makemigrations \
    && python3 manage.py migrate \
    && if echo "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.create_superuser('${USER}', 'www@mrdoc.fun', '${MM}')" | python manage.py shell;then printf "$(date) user:%s pwd:%s\n" "$USER" "$MM" >>/opt/jonnyan404/"${GIT_DIR}"pwdinfo.log; fi \
    && deactivate
    
    if [[ $? -ne 0 ]]; then
        colorEcho ${RED} "MrDoc 安装过程中出现错误"
        return 1
    fi
    
    return 0
}

initconfig(){
###  Generate uwsgi configuration file ###
if [[ ! -f "/opt/jonnyan404/${GIT_DIR}_uwsgi.ini" ]]; then
cat >"/opt/jonnyan404/${GIT_DIR}_uwsgi.ini"<<EOF
[uwsgi]

# Django-related settings
http            = :${mrdocport:-10086}
# the base directory (full path)
chdir           = /opt/jonnyan404/${GIT_DIR}
# Django's wsgi file
module          = ${GIT_DIR}.wsgi:application
wsgi-file       = ${GIT_DIR}/wsgi.py
# the virtualenv (full path)
home            = /opt/jonnyan404/${GIT_DIR}_env
logto = /opt/jonnyan404/mrdoc_uwsgi_log.log

# process-related settings
# master
master          = true
# maximum number of worker processes
processes       = 5
# the socket (use the full path to be safe
socket          = /opt/jonnyan404/${GIT_DIR}.sock
# ... with appropriate permissions - may be needed
chmod-socket    = 666
# clear environment on exit
vacuum          = true
EOF
fi
### Generate nginx configuration file ###
if [[ ! -f "/opt/jonnyan404/${GIT_DIR}_nginx_jonnyan404.conf" ]]; then
cat >"/opt/jonnyan404/${GIT_DIR}_nginx_jonnyan404.conf"<<EOF
server {
    # the port your site will be served on
    listen      80;
    # the domain name it will serve for
    server_name _; # substitute your machine's IP address or FQDN
    charset     utf-8;
    access_log /var/log/nginx/${GIT_DIR}-nginx-access.log;
    error_log  /var/log/nginx/${GIT_DIR}-nginx-error.log;
    # max upload size
    client_max_body_size 75M;   # adjust to taste

    # Django media
    location /media  {
        alias /opt/jonnyan404/${GIT_DIR}/media;  # your Django project's media files - amend as required
    }

    location /static {
        alias /opt/jonnyan404/${GIT_DIR}/static; # your Django project's static files - amend as required
    }

    # Finally, send all non-media requests to the Django server.
    location / {
        uwsgi_pass  unix:///opt/jonnyan404/${GIT_DIR}.sock;
        include     /etc/nginx/uwsgi_params; # the uwsgi_params file you installed
    }
}
EOF
fi
### Generate mrdoc sample configuration file ###
if [[ ! -f "/opt/jonnyan404/${GIT_DIR}/config/config_sample.ini" ]]; then
cat >"/opt/jonnyan404/${GIT_DIR}/config/config_sample.ini"<<EOF
[site]
# True表示开启站点调试模式，False表示关闭站点调试模式
debug = False
[database]
# engine，指定数据库类型，接受sqlite、mysql、oracle、postgresql
engine = mysql
# name表示数据库的名称
name = db_name
# user表示数据库用户名
user = db_user
# password表示数据库用户密码
password = db_pwd
# host表示数据库主机地址
host = db_host
# port表示数据库端口
port = db_port
[selenium]
# PDF相关配置项
# 在Windows环境下测试或使用，请配置driver = Chrome，否则不用配置 driver 参数
driver = Chrome
# 如果系统无法正确安装或识别chromedriver，请指定chromedriver在计算机上的绝对路径
driver_path = driver_path
[cors_origin]
allow = http://localhost,capacitor://localhost
# 专业版更多配置请查看文档 "https://doc.mrdoc.pro/doc/3445/"
EOF
fi
### Generate systemd configuration file ###
if [[ -n "${SYSTEMCTL_CMD}" ]];then
cat>"/opt/jonnyan404/${GIT_DIR}fun.service"<<EOF
[Unit]
Description=mrdoc service by jonnyan404
Requires=network.target
After=network.target
After=syslog.target

[Service]
TimeoutStartSec=0
RestartSec=3
Restart=always
KillSignal=SIGQUIT
Type=notify
NotifyAccess=all
StandardError=syslog
RuntimeDirectory=uwsgi
# Main call: Virtual env is activated and uwsgi is started with INI file as argument
ExecStart=/bin/bash -c 'cd /opt/jonnyan404/; source ${GIT_DIR}_env/bin/activate; uwsgi --ini /opt/jonnyan404/${GIT_DIR}_uwsgi.ini'

[Install]
WantedBy=multi-user.target
EOF
else
colorEcho  ${RED}  "systemd配置生成失败,请确认系统支持并存在systemd服务!"
fi
return
}

start(){
    systemctl daemon-reload
    if systemctl start "${GIT_DIR}"fun;then
        colorEcho  ${GREEN} "启动${GIT_DIR}成功"
    else
        systemctl status "${GIT_DIR}"fun -l
        colorEcho  ${RED} "启动${GIT_DIR}失败"
    fi
}

stop(){
    systemctl daemon-reload
    if systemctl stop "${GIT_DIR}"fun;then
        colorEcho  ${GREEN} "停止${GIT_DIR}成功"
    else
        systemctl status "${GIT_DIR}"fun -l
        colorEcho  ${RED} "停止${GIT_DIR}失败"
    fi
}

status(){
    systemctl daemon-reload
    systemctl status "${GIT_DIR}"fun -l
}

showlog(){
    cat /opt/jonnyan404/mrdoc_uwsgi_log.log
}

restart(){
    systemctl daemon-reload
    if systemctl restart "${GIT_DIR}"fun;then
        colorEcho  ${GREEN} "重启${GIT_DIR}成功"
    else
        systemctl status "${GIT_DIR}"fun -l
        colorEcho  ${RED} "重启${GIT_DIR}失败"
    fi
}

enable(){
    systemctl daemon-reload
    if systemctl enable "${GIT_DIR}"fun;then
        colorEcho  ${GREEN} "设置${GIT_DIR}开机自启成功"
    else
        colorEcho  ${RED} "设置${GIT_DIR}开机自启失败"
    fi
}

remove(){
    echo "执行卸载中(卸载采用软删除,彻底删除请到/tmp目录手动删除!)"
    systemctl stop "${GIT_DIR}"fun
    cp -rf /opt/jonnyan404 /tmp
    rm -rf /opt/jonnyan404
    rm -f /etc/systemd/system/"${GIT_DIR}"fun.service
    systemctl daemon-reload
    colorEcho  ${GREEN} "卸载完成!"

}

update(){
    MRDOCDIR=/opt/jonnyan404
    cd ${MRDOCDIR}/"${GIT_DIR}" && git pull
    source ${MRDOCDIR}/"${GIT_DIR}"_env/bin/activate \
    && cd ${MRDOCDIR}/"${GIT_DIR}" \
    && pip3 install -r requirements.txt \
    && python3 manage.py makemigrations \
    && python3 manage.py migrate \
    && deactivate
    colorEcho  ${YELLOW} "如果此步有报错,请查看官网关于升级的要求(一般是缺少系统依赖)或者群内咨询."
}

changepwd(){
    if [[ $GIT_DIR == "MrDocPro" ]] ;then
        colorEcho  ${BLUE}  "###修改专业版密码中...当前用户是:${cuser}###"
    else
        colorEcho  ${BLUE}  "###修改开源版密码中...当前用户是:${cuser}###"
    fi
    MRDOCDIR=/opt/jonnyan404
    source ${MRDOCDIR}/"${GIT_DIR}"_env/bin/activate \
    && python3 ${MRDOCDIR}/"${GIT_DIR}"/manage.py changepassword ${cuser}
}

createsu(){
    if [[ $GIT_DIR == "MrDocPro" ]] ;then
        colorEcho  ${BLUE}  "###创建 专业版管理员 用户中...###"
    else
        colorEcho  ${BLUE}  "###创建 开源版管理员 用户中...###"
    fi
    MRDOCDIR=/opt/jonnyan404
    source ${MRDOCDIR}/"${GIT_DIR}"_env/bin/activate \
    && python3 ${MRDOCDIR}/"${GIT_DIR}"/manage.py createsuperuser
}

via(){
    MRDOCDIR=/opt/jonnyan404
    cd ${MRDOCDIR}/"${GIT_DIR}"

    if source ${MRDOCDIR}/"${GIT_DIR}"_env/bin/activate;then
        cd ${MRDOCDIR}/"${GIT_DIR}" 
        colorEcho  ${BLUE} "当前已进入虚拟环境内,如需推出虚拟环境,可直接关闭shell窗口或者当前窗口执行 deactivate 命令."
    else
        colorEcho  ${RED} "进入虚拟环境失败,请检查你的命令是否输入正确."
    fi
}

initdb(){
    MRDOCDIR=/opt/jonnyan404
    USER="admin"
    MM=$(cat /proc/sys/kernel/random/uuid| cut -f1 -d "-")

    mkdir -p ${MRDOCDIR}
    touch ${MRDOCDIR}/"${GIT_DIR}"pwdinfo.log
    source ${MRDOCDIR}/"${GIT_DIR}"_env/bin/activate \
    && pip3 install --upgrade pip \
    && cd ${MRDOCDIR}/"${GIT_DIR}" \
    && python3 manage.py makemigrations \
    && python3 manage.py migrate \
    && if echo "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.create_superuser('${USER}', 'www@mrdoc.fun', '${MM}')" | python manage.py shell;then printf "$(date) user:%s pwd:%s\n" "$USER" "$MM" >>/opt/jonnyan404/"${GIT_DIR}"pwdinfo.log; fi \
    && deactivate
    colorEcho  ${YELLOW} "如果此步有报错,一般是数据库版本和数据库配置问题."
    colorEcho  ${GREEN} "执行完毕,当前账号密码为:${USER}和${MM}"
}

Help(){
    colorEcho  ${BLUE}  "如需修改 mrdoc 配置文件,请到 /opt/jonnyan404/ 目录下"
    echo "-------"
    echo "./mrdoc.sh [-h] [-i link] [-start pro] [-stop pro] [-status pro] [-restart pro] [-u pro] [-c] [--remove pro] [-v] [--changepwd user pro] [--createsu pro] [--initdb pro]"
    echo "  -h, --help              Show help | 展示帮助选项"
    echo "  -i, --install           To install mrdoc | 安装 mrdoc"
    echo "  -start, --start         Start mrdoc | 启动 mrdoc"
    echo "  -stop, --stop           Stop mrdoc | 停止 mrdoc"
    echo "  -status, --status       mrdoc status | 查看 mrdoc 当前运行状态"
    echo "  -showlog, --showlog     Show uwsgi log | 查看 uwsgi 日志"
    echo "  -restart, --restart     Restart mrdoc | 重启 mrdoc"
    echo "  -u, --update            Update mrdoc version | 更新 mrdoc 源码"
    echo "      --via               Enter the virtual environment. | 进入 mrdoc 虚拟环境"
    echo "      --remove            Remove installed mrdoc | 卸载 mrdoc"
    echo "  -c, --check             Check for update | 检查mrdoc安装脚本是否可更新"
    echo "  -v, --version           Look script version | 查看脚本版本号"
    echo "      --changepwd         Changepassword | 修改用户密码"
    echo "      --createsu          Createsuperuser | 创建新的管理员用户"
    echo "      --initdb            Initialize database | 初始化数据库,更换数据库时需要执行."
    return 0
}


main(){
    if installdepend ;then
        if [[ $(echo $GIT_LINK | grep "git.mrdoc.pro/MrDoc/MrDocPro") != "" ]];then
            GIT_DIR=$(echo $GIT_LINK|grep -e "MrDocPro" -o)
            echo $GIT_DIR
            colorEcho  ${BLUE}  "###安装 mrdoc 专业版中...###"
        else
            GIT_LINK="https://gitee.com/zmister/MrDoc.git"
            GIT_DIR=$(echo $GIT_LINK|grep -e "MrDoc"  -o)
            colorEcho  ${BLUE}  "###安装 mrdoc 开源版中...###"
        fi
        
        if ! installmrdoc; then
            colorEcho  ${RED}  "MrDoc 安装失败"
            return 1
        fi
        
        colorEcho  ${BLUE}  "###初始化配置中...###"
        initconfig
        ln -sf /opt/jonnyan404/"${GIT_DIR}"fun.service /etc/systemd/system/"${GIT_DIR}"fun.service
        colorEcho  ${BLUE}  "###写入环境变量...###"
        chmod a+x "${WORK_PATH}"/mrdoc.sh 
        ln -sf "${WORK_PATH}"/mrdoc.sh /bin/mrdoc
        colorEcho  ${BLUE}  "###启动mrdoc...###"
        if start;then
            # systemctl status "${GIT_DIR}"fun -l
            colorEcho  ${GREEN}  "$(cat /opt/jonnyan404/${GIT_DIR}pwdinfo.log),Password is saved in /opt/jonnyan404/${GIT_DIR}pwdinfo.log"
            colorEcho  ${GREEN}  "如果上方没显示账号密码,就是部署失败,请反馈至https://gitee.com/jonnyan404/oh-my-mrdoc/issues"
        else
            colorEcho  ${RED}  "部署失败,请反馈至https://gitee.com/jonnyan404/oh-my-mrdoc/issues"
            systemctl status "${GIT_DIR}"fun -l
        fi
    else
        colorEcho  ${RED}  "依赖安装失败"
        return 1
    fi
}

#########################
while [[ $# -gt 0 ]];do
    key="$1"
    case $key in
        -h|--help)
        Help
        ;;
        -i|--install)
        GIT_LINK=$2
        main
        shift # past argument
        ;;
        -start|--start)
        if [[ "$2" == "pro" ]] ;then
            GIT_DIR=MrDocPro
            shift
        else
            GIT_DIR=MrDoc
        fi
        start
        ;;
        -stop|--stop)
        if [[ "$2" == "pro" ]] ;then
            GIT_DIR=MrDocPro
            shift
        else
            GIT_DIR=MrDoc
        fi
        stop
        ;;
        -status|--status)
        if [[ "$2" == "pro" ]] ;then
            GIT_DIR=MrDocPro
            shift
        else
            GIT_DIR=MrDoc
        fi
        status
        ;;
        -showlog|--showlog)
        showlog
        ;;
        -restart|--restart)
        if [[ "$2" == "pro" ]] ;then
            GIT_DIR=MrDocPro
            shift
        else
            GIT_DIR=MrDoc
        fi
        restart
        ;;
        --enable)
        if [[ "$2" == "pro" ]] ;then
            GIT_DIR=MrDocPro
            shift
        else
            GIT_DIR=MrDoc
        fi
        enable
        ;;
        -v|--version)
        echo "当前版本号:${SCR_VERSION}"
        #shift
        ;;
        -u|--update)
        if [[ "$2" == "pro" ]] ;then
            GIT_DIR=MrDocPro
            shift
        else
            GIT_DIR=MrDoc
        fi
        update
        ;;
        --via)
        if [[ "$2" == "pro" ]] ;then
            GIT_DIR=MrDocPro
            shift
        else
            GIT_DIR=MrDoc
        fi
        via
        ;;
        --remove)
        if [[ "$2" == "pro" ]] ;then
            GIT_DIR=MrDocPro
            shift
        else
            GIT_DIR=MrDoc
        fi
        remove
        ;;
        -c|--check)
        colorEcho  ${YELLOW} "暂未实现"
        ;;
        --changepwd)
        if [[ "$2" != "" ]] ;then
            cuser=$2
            if [[ "$3" == "pro" ]] ;then
                GIT_DIR=MrDocPro
                shift
            else
                GIT_DIR=MrDoc
            fi
            changepwd
            shift
        else
            colorEcho  ${RED}  "请指定用户名..."
        fi
        ;;
        --createsu)
        if [[ "$2" == "pro" ]] ;then
            GIT_DIR=MrDocPro
            shift
        else
            GIT_DIR=MrDoc
        fi
        createsu
        ;;
        --initdb)
        if [[ "$2" == "pro" ]] ;then
            GIT_DIR=MrDocPro
            shift
        else
            GIT_DIR=MrDoc
        fi
        initdb
        ;;
        *)
        colorEcho  ${RED}  "指令错误,请重新输入..."        # unknown option
        ;;
    esac
    shift # past argument or value
done

###############################
