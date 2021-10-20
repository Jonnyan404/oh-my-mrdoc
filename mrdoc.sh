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
SCR_VERSION="2021.10.20"
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
        apt-get -qq update
        SOFTWARE_UPDATED=1
        fi
        apt-get -y  install git pwgen python3 python3-dev python3-pip gcc wheel python3-setuptools python3-venv
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
    touch ${MRDOCDIR}/pwdinfo.log
    cd ${MRDOCDIR} && git clone https://gitee.com/zmister/MrDoc.git
    pip3 install uwsgi
    python3 -m venv ${MRDOCDIR}/mrdoc_env
    source ${MRDOCDIR}/mrdoc_env/bin/activate \
    && pip install --upgrade pip \
    && cd ${MRDOCDIR}/MrDoc \
    && pip3 install -r requirements.txt \
    && python3 manage.py makemigrations \
    && python3 manage.py migrate \
    && if echo "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.create_superuser('${USER}', 'www@mrdoc.fun', '${MM}')" | python manage.py shell;then printf "$(date) user:%s pwd:%s\n" "$USER" "$MM" >>/opt/jonnyan404/pwdinfo.log; fi \
    && deactivate
}

initconfig(){
###  Generate uwsgi configuration file ###
    if [[ ! -f "/opt/jonnyan404/mrdoc_uwsgi.ini" ]]; then
cat >"/opt/jonnyan404/mrdoc_uwsgi.ini"<<EOF
[uwsgi]

# Django-related settings
http            = :${port:-10086}
# the base directory (full path)
chdir           = /opt/jonnyan404/MrDoc
# Django's wsgi file
module          = MrDoc.wsgi:application
wsgi-file       = MrDoc/wsgi.py
# the virtualenv (full path)
home            = /opt/jonnyan404/mrdoc_env

# process-related settings
# master
master          = true
# maximum number of worker processes
processes       = 5
# the socket (use the full path to be safe
socket          = /opt/jonnyan404/mrdoc.sock
# ... with appropriate permissions - may be needed
chmod-socket    = 666
# clear environment on exit
vacuum          = true
EOF
    fi
### Generate nginx configuration file ###
    if [[ ! -f "/opt/jonnyan404/mrdoc_nginx_jonnyan404.conf" ]]; then
cat >"/opt/jonnyan404/mrdoc_nginx_jonnyan404.conf"<<EOF
server {
    # the port your site will be served on
    listen      80;
    # the domain name it will serve for
    server_name _; # substitute your machine's IP address or FQDN
    charset     utf-8;
    access_log /var/log/nginx/mrdoc-nginx-access.log;
    error_log  /var/log/nginx/mrdoc-nginx-error.log;
    # max upload size
    client_max_body_size 75M;   # adjust to taste

    # Django media
    location /media  {
        alias /opt/jonnyan404/MrDoc/media;  # your Django project's media files - amend as required
    }

    location /static {
        alias /opt/jonnyan404/MrDoc/static; # your Django project's static files - amend as required
    }

    # Finally, send all non-media requests to the Django server.
    location / {
        uwsgi_pass  unix:///opt/jonnyan404/mrdoc.sock;
        include     /etc/nginx/uwsgi_params; # the uwsgi_params file you installed
    }
}
EOF
    fi
### Generate systemd configuration file ###
if [[ -n "${SYSTEMCTL_CMD}" ]];then
cat>"/opt/jonnyan404/mrdocfun.service"<<EOF
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
ExecStart=/bin/bash -c 'cd /opt/jonnyan404/; source mrdoc_env/bin/activate; uwsgi --ini /opt/jonnyan404/mrdoc_uwsgi.ini'

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
    if systemctl start mrdocfun;then
        return 0
    else
        return 1
    fi
}

stop(){
    systemctl daemon-reload
    if systemctl stop mrdocfun;then
        return 0
    else
        return 1
    fi
}

restart(){
    systemctl daemon-reload
    if systemctl restart mrdocfun;then
        return 0
    else
        return 1
    fi
}

remove(){
    echo "执行卸载中(卸载采用软删除,彻底删除请到/tmp目录手动删除!),请等待..."
    systemctl stop mrdocfun
    mv -f /opt/jonnyan404 /tmp/
    mv -f /etc/systemd/system/mrdocfun.service /tmp/
    systemctl daemon-reload
    colorEcho  ${GREEN} "卸载完成!"

}

update(){
    MRDOCDIR=/opt/jonnyan404
    cd ${MRDOCDIR}/MrDoc && git pull
    source ${MRDOCDIR}/mrdoc_env/bin/activate \
    && cd ${MRDOCDIR}/MrDoc \
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
    echo "  -v, --version           Look script version | 查看脚本版本号"
    echo "  -u, --update            Update mrdoc version | 更新 mrdoc 源码"
    echo "      --remove            Remove installed mrdoc | 卸载 mrdoc"
    echo "  -c, --check             Check for update | 检查mrdoc安装脚本是否可更新"
    return 0
}

main(){
    if installdepend ;then
        colorEcho  ${BLUE}  "###安装mrdoc中...###"
        installmrdoc
        colorEcho  ${BLUE}  "###初始化配置中...###"
        initconfig
        ln -sf /opt/jonnyan404/mrdocfun.service /etc/systemd/system/mrdocfun.service
        colorEcho  ${BLUE}  "###启动mrdoc...###"
        if start;then
            systemctl status mrdocfun
            colorEcho  ${GREEN}  "$(cat /opt/jonnyan404/pwdinfo.log),Password is saved in /opt/jonnyan404/pwdinfo.log"
            colorEcho  ${GREEN}  "如果上方没显示账号密码,就是部署失败,请进群\@亖\反馈!QQ群号:735507293"
        else
            colorEcho  ${RED}  "部署失败,请进群\@亖\反馈!QQ群号:735507293"
            systemctl status mrdoc
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
        main
        #shift # past argument
        ;;
        -start|--start)
        start
        ;;
        -stop|--stop)
        stop
        ;;
        -restart|--restart)
        restart
        ;;
        -v|--version)
        echo "当前版本号:${SCR_VERSION}"
        #shift
        ;;
        -u|--update)
        update
        ;;
        --remove)
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
