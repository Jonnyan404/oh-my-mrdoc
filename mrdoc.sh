#!/bin/bash
# DATE: 2021-4-15 11:55:47
# Author: create by jonnyan404
# Blog:https://www.mrdoc.fun
# Description:This script is auto install mrdoc project
# Version:1.0

SYSTEMCTL_CMD=$(command -v systemctl 2>/dev/null)
#MYDIR=$(dirname "$0")
#SERVICE_CMD=$(command -v service 2>/dev/null)
SOFTWARE_UPDATED=0
SCR_VERSION="2021.10.21"
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
        colorEcho ${BLUE} "Updating software repo"
        apt-get  update
        SOFTWARE_UPDATED=1
        fi
        apt-get -y  install git pwgen python3 python3-dev python3-pip gcc python3-wheel python3-setuptools python3-venv
    elif [[ -n $(command -v yum) ]]; then
        if [[ $SOFTWARE_UPDATED -eq 0 ]]; then
        colorEcho ${BLUE} "Updating software repo"
        yum -q makecache
        SOFTWARE_UPDATED=1
        fi
        yum -y  install epel-release git pwgen python3 python3-devel python3-pip
        sqliteversion=$(sqlite3 -version|awk '{print $1}')
        res=$(expr "$sqliteversion" \> 3.8.3)
        if [ "$res" -eq 0 ];then
            yum -y remove  sqlite-devel
            wget -O /tmp/sqlite.rpm https://kojipkgs.fedoraproject.org//packages/sqlite/3.8.11/1.fc21/x86_64/sqlite-3.8.11-1.fc21.x86_64.rpm
            if ! yum -y install /tmp/sqlite.rpm ;then
                wget -O /tmp/ https://www.sqlite.org/2020/sqlite-autoconf-3340000.tar.gz
                tar zxvf /tmp/sqlite-autoconf-3340000.tar.gz
                cd /tmp/sqlite-autoconf-3340000 || exit \
                && ./configure --prefix=/usr/local \
                && make && make install
                mv /usr/bin/sqlite3  /usr/bin/sqlite3_backup
                ln -s /usr/local/bin/sqlite3   /usr/bin/sqlite3
                echo "/usr/local/lib" > /etc/ld.so.conf.d/sqlite3.conf
                ldconfig
                sqlite3 -version
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
    MM=$(pwgen -1s)

    mkdir -p ${MRDOCDIR}
    touch ${MRDOCDIR}/"${GIT_DIR}"pwdinfo.log
    cd ${MRDOCDIR} && git clone ${GIT_LINK}
    pip3 install uwsgi
    python3 -m venv ${MRDOCDIR}/"${GIT_DIR}"_env
    source ${MRDOCDIR}/"${GIT_DIR}"_env/bin/activate \
    && pip install --upgrade pip \
    && cd ${MRDOCDIR}/"${GIT_DIR}" \
    && pip3 install -r requirements.txt \
    && python3 manage.py makemigrations \
    && python3 manage.py migrate \
    && if echo "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.create_superuser('${USER}', 'www@mrdoc.fun', '${MM}')" | python manage.py shell;then printf "$(date) user:%s pwd:%s\n" "$USER" "$MM" >>/opt/jonnyan404/"${GIT_DIR}"pwdinfo.log; fi \
    && deactivate
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
        systemctl status "${GIT_DIR}"fun
        colorEcho  ${RED} "启动${GIT_DIR}失败"
    fi
}

stop(){
    systemctl daemon-reload
    if systemctl stop "${GIT_DIR}"fun;then
        colorEcho  ${GREEN} "停止${GIT_DIR}成功"
    else
        systemctl status "${GIT_DIR}"fun
        colorEcho  ${RED} "停止${GIT_DIR}失败"
    fi
}

restart(){
    systemctl daemon-reload
    if systemctl restart "${GIT_DIR}"fun;then
        colorEcho  ${GREEN} "重启${GIT_DIR}成功"
    else
        systemctl status "${GIT_DIR}"fun
        colorEcho  ${RED} "重启${GIT_DIR}失败"
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

Help(){
    echo "./mrdoc.sh [-h] [-i] [-start] [-stop] [-restart] [-u] [-c] [--remove] [-v]"
    echo "  -h, --help              Show help | 展示帮助选项"
    echo "  -i, --install           To install mrdoc | 安装 mrdoc"
    echo "  -start, --start         Start mrdoc | 启动 mrdoc"
    echo "  -stop, --stop           Stop mrdoc | 停止 mrdoc"
    echo "  -restart, --restart     Restart mrdoc | 重启 mrdoc"
    echo "  -u, --update            Update mrdoc version | 更新 mrdoc 源码"
    echo "      --remove            Remove installed mrdoc | 卸载 mrdoc"
    echo "  -c, --check             Check for update | 检查mrdoc安装脚本是否可更新"
    echo "  -v, --version           Look script version | 查看脚本版本号"
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
        installmrdoc
        colorEcho  ${BLUE}  "###初始化配置中...###"
        initconfig
        ln -sf /opt/jonnyan404/"${GIT_DIR}"fun.service /etc/systemd/system/"${GIT_DIR}"fun.service
        colorEcho  ${BLUE}  "###启动mrdoc...###"
        if start;then
            systemctl status "${GIT_DIR}"fun
            colorEcho  ${GREEN}  "$(cat /opt/jonnyan404/${GIT_DIR}pwdinfo.log),Password is saved in /opt/jonnyan404/${GIT_DIR}pwdinfo.log"
            colorEcho  ${GREEN}  "如果上方没显示账号密码,就是部署失败,请进群\@亖\反馈!QQ群号:735507293"
        else
            colorEcho  ${RED}  "部署失败,请进群\@亖\反馈!QQ群号:735507293"
            systemctl status "${GIT_DIR}"
        fi
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
        -restart|--restart)
        if [[ "$2" == "pro" ]] ;then
            GIT_DIR=MrDocPro
            shift
        else
            GIT_DIR=MrDoc
        fi
        restart
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
        *)
        colorEcho  ${RED}  "指令错误,请重新输入..."        # unknown option
        ;;
    esac
    shift # past argument or value
done

###############################
