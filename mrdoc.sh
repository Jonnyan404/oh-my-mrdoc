#!/bin/bash
# DATE: 2021-4-15 11:55:47
# Author: create by jonnyan404
# Blog:https://www.mrdoc.fun
# Description:This script is auto install mrdoc project
# Version:1.4

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
        apt-get update
        SOFTWARE_UPDATED=1
        fi
        apt-get -y install git python3 python3-dev python3-pip gcc python3-wheel python3-setuptools python3-venv libldap2-dev libsasl2-dev libmariadb-dev
    elif [[ -n $(command -v yum) ]]; then
        if [[ $SOFTWARE_UPDATED -eq 0 ]]; then
        colorEcho ${BLUE} "Centos Updating software repo"
        yum -q makecache
        SOFTWARE_UPDATED=1
        fi
        yum -y install epel-release git python3 python3-devel python3-pip gcc openldap openldap-devel openssl-devel
        yum -y insatll mariadb-devel
        yum -y insatll mysql-devel
        sqliteversion=$(sqlite3 -version|awk '{print $1}')
        function version_ge() { test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" == "$1"; }
        if version_ge $sqliteversion "3.8.3"; then
	      colorEcho ${BLUE} "Sqlite3 Version ${sqliteversion} Support!"
        else
		    colorEcho ${YELLOW} "Sqlite3 Version ${sqliteversion} Not Support,Install New Version..."
            yum -y remove  sqlite-devel
            wget -O /tmp/sqlite.rpm https://kojipkgs.fedoraproject.org//packages/sqlite/3.8.11/1.fc21/x86_64/sqlite-3.8.11-1.fc21.x86_64.rpm
            if ! yum -y install /tmp/sqlite.rpm ;then
                tar -zxvf "$WORK_PATH"/sqlite-autoconf-3340000.tar.gz -C /tmp
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
    MM=$(cat /proc/sys/kernel/random/uuid| cut -f1 -d "-")

    mkdir -p ${MRDOCDIR}
    touch ${MRDOCDIR}/"${GIT_DIR}"pwdinfo.log
    cd ${MRDOCDIR} && git clone ${GIT_LINK}
    pip3 install uwsgi
    python3 -m venv ${MRDOCDIR}/"${GIT_DIR}"_env
    source ${MRDOCDIR}/"${GIT_DIR}"_env/bin/activate \
    && pip3 install --upgrade pip \
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
# True?????????????????????????????????False??????????????????????????????
debug = False
[database]
# engine?????????????????????????????????sqlite???mysql???oracle???postgresql
engine = mysql
# name????????????????????????
name = db_name
# user????????????????????????
user = db_user
# password???????????????????????????
password = db_pwd
# host???????????????????????????
host = db_host
# port?????????????????????
port = db_port
[selenium]
# PDF???????????????
# ???Windows????????????????????????????????????driver = Chrome????????????????????? driver ??????
driver = Chrome
# ???????????????????????????????????????chromedriver????????????chromedriver??????????????????????????????
driver_path = driver_path
[cors_origin]
allow = http://localhost,capacitor://localhost
# ???????????????????????????????????? "https://doc.mrdoc.pro/doc/3445/"
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
colorEcho  ${RED}  "systemd??????????????????,??????????????????????????????systemd??????!"
fi
return
}

start(){
    systemctl daemon-reload
    if systemctl start "${GIT_DIR}"fun;then
        colorEcho  ${GREEN} "??????${GIT_DIR}??????"
    else
        systemctl status "${GIT_DIR}"fun -l
        colorEcho  ${RED} "??????${GIT_DIR}??????"
    fi
}

stop(){
    systemctl daemon-reload
    if systemctl stop "${GIT_DIR}"fun;then
        colorEcho  ${GREEN} "??????${GIT_DIR}??????"
    else
        systemctl status "${GIT_DIR}"fun -l
        colorEcho  ${RED} "??????${GIT_DIR}??????"
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
        colorEcho  ${GREEN} "??????${GIT_DIR}??????"
    else
        systemctl status "${GIT_DIR}"fun -l
        colorEcho  ${RED} "??????${GIT_DIR}??????"
    fi
}

remove(){
    echo "???????????????(?????????????????????,??????????????????/tmp??????????????????!)"
    systemctl stop "${GIT_DIR}"fun
    cp -rf /opt/jonnyan404 /tmp
    rm -rf /opt/jonnyan404
    rm -f /etc/systemd/system/"${GIT_DIR}"fun.service
    systemctl daemon-reload
    colorEcho  ${GREEN} "????????????!"

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
    colorEcho  ${YELLOW} "?????????????????????,????????????????????????????????????(???????????????????????????)??????????????????."
}

changepwd(){
    if [[ $GIT_DIR == "MrDocPro" ]] ;then
        colorEcho  ${BLUE}  "###????????????????????????...???????????????:${cuser}###"
    else
        colorEcho  ${BLUE}  "###????????????????????????...???????????????:${cuser}###"
    fi
    MRDOCDIR=/opt/jonnyan404
    source ${MRDOCDIR}/"${GIT_DIR}"_env/bin/activate \
    && python3 ${MRDOCDIR}/"${GIT_DIR}"/manage.py changepassword ${cuser}
}

createsu(){
    if [[ $GIT_DIR == "MrDocPro" ]] ;then
        colorEcho  ${BLUE}  "###?????? ?????????????????? ?????????...###"
    else
        colorEcho  ${BLUE}  "###?????? ?????????????????? ?????????...###"
    fi
    MRDOCDIR=/opt/jonnyan404
    source ${MRDOCDIR}/"${GIT_DIR}"_env/bin/activate \
    && python3 ${MRDOCDIR}/"${GIT_DIR}"/manage.py createsuperuser
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
    colorEcho  ${YELLOW} "?????????????????????,????????????????????????????????????????????????."
    colorEcho  ${GREEN} "????????????,?????????????????????:${USER}???${MM}"
}

Help(){
    colorEcho  ${BLUE}  "???????????? mrdoc ????????????,?????? /opt/jonnyan404/ ?????????"
    echo "-------"
    echo "./mrdoc.sh [-h] [-i link] [-start pro] [-stop pro] [-status pro] [-restart pro] [-u pro] [-c] [--remove pro] [-v] [--changepwd user pro] [--createsu pro] [--initdb pro]"
    echo "  -h, --help              Show help | ??????????????????"
    echo "  -i, --install           To install mrdoc | ?????? mrdoc"
    echo "  -start, --start         Start mrdoc | ?????? mrdoc"
    echo "  -stop, --stop           Stop mrdoc | ?????? mrdoc"
    echo "  -status, --status       mrdoc status | ?????? mrdoc ??????????????????"
    echo "  -showlog, --showlog     Show uwsgi log | ?????? uwsgi ??????"
    echo "  -restart, --restart     Restart mrdoc | ?????? mrdoc"
    echo "  -u, --update            Update mrdoc version | ?????? mrdoc ??????"
    echo "      --remove            Remove installed mrdoc | ?????? mrdoc"
    echo "  -c, --check             Check for update | ??????mrdoc???????????????????????????"
    echo "  -v, --version           Look script version | ?????????????????????"
    echo "      --changepwd         Changepassword | ??????????????????"
    echo "      --createsu          Createsuperuser | ???????????????????????????"
    echo "      --initdb            Initialize database | ??????????????????,??????????????????????????????."
    return 0
}


main(){
    if installdepend ;then
        if [[ $(echo $GIT_LINK | grep "git.mrdoc.pro/MrDoc/MrDocPro") != "" ]];then
            GIT_DIR=$(echo $GIT_LINK|grep -e "MrDocPro" -o)
            echo $GIT_DIR
            colorEcho  ${BLUE}  "###?????? mrdoc ????????????...###"
        else
            GIT_LINK="https://gitee.com/zmister/MrDoc.git"
            GIT_DIR=$(echo $GIT_LINK|grep -e "MrDoc"  -o)
            colorEcho  ${BLUE}  "###?????? mrdoc ????????????...###"
        fi
        installmrdoc
        colorEcho  ${BLUE}  "###??????????????????...###"
        initconfig
        ln -sf /opt/jonnyan404/"${GIT_DIR}"fun.service /etc/systemd/system/"${GIT_DIR}"fun.service
        colorEcho  ${BLUE}  "###??????????????????...###"
        chmod a+x "${WORK_PATH}"/mrdoc.sh 
        ln -sf "${WORK_PATH}"/mrdoc.sh /bin/mrdoc
        colorEcho  ${BLUE}  "###??????mrdoc...###"
        if start;then
            # systemctl status "${GIT_DIR}"fun -l
            colorEcho  ${GREEN}  "$(cat /opt/jonnyan404/${GIT_DIR}pwdinfo.log),Password is saved in /opt/jonnyan404/${GIT_DIR}pwdinfo.log"
            colorEcho  ${GREEN}  "?????????????????????????????????,??????????????????,?????????\@???\??????!QQ??????:735507293"
        else
            colorEcho  ${RED}  "????????????,?????????\@???\??????!QQ??????:735507293"
            systemctl status "${GIT_DIR}"fun -l
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
        -v|--version)
        echo "???????????????:${SCR_VERSION}"
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
        colorEcho  ${YELLOW} "????????????"
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
            colorEcho  ${RED}  "??????????????????..."
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
        colorEcho  ${RED}  "????????????,???????????????..."        # unknown option
        ;;
    esac
    shift # past argument or value
done

###############################
