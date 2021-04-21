#!/bin/bash
# DATE: 2021-4-15 11:55:47
# Author: create by jonnyan404
# Blog:https://www.mrdoc.fun
# Description:This script is auto install mrdoc project
# Version:1.0

SYSTEMCTL_CMD=$(command -v systemctl 2>/dev/null)
SERVICE_CMD=$(command -v service 2>/dev/null)
SOFTWARE_UPDATED=0
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
        apt-get -y  install git pwgen python3 python3-dev python3-pip nginx 

    elif [[ -n $(command -v yum) ]]; then
        if [[ $SOFTWARE_UPDATED -eq 0 ]]; then
        colorEcho ${BLUE} "Updating software repo"
        yum -q makecache
        SOFTWARE_UPDATED=1
        fi
        yum -y  install epel-release git pwgen python3 python3-devel python3-pip nginx 
        yum -y remove  sqlite-devel
        wget -O /tmp/sqlite.rpm https://kojipkgs.fedoraproject.org//packages/sqlite/3.8.11/1.fc21/x86_64/sqlite-3.8.11-1.fc21.x86_64.rpm
        yum -y install /tmp/sqlite.rpm
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
    listen      ${port:-10086};
    # the domain name it will serve for
    server_name _; # substitute your machine's IP address or FQDN
    charset     utf-8;
    access_log /opt/jonnyan404/mrdoc-nginx-access.log;
    error_log  /opt/jonnyan404/mrdoc-nginx-error.log;
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
        if [[ ! -f "/etc/systemd/system/mrdoc.service" ]]; then
            if [[ ! -f "/lib/systemd/system/mrdoc.service" ]]; then
cat>"/etc/systemd/system/mrdoc.service"<<EOF
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
            fi
        fi
        return
    fi
    return
}

start(){
    systemctl daemon-reload
    if systemctl start mrdoc;then
        return 0
    else
        return 1
    fi
}

stop(){
    systemctl stop mrdoc
}

main(){
    nginxcount=$(ps -ef|grep nginx|wc -l)
    if installdepend ;then
        installmrdoc
        initconfig
        if start;then
            if [ $nginxcount -eq 1 ];then
                if systemctl start nginx ;then
                    cp /opt/jonnyan404/mrdoc_nginx_jonnyan404.conf /etc/nginx/conf.d/
                    if nginx -t ;then
                        nginx -s reload
                    else
                        colorEcho  ${RED} "Please check your nginx configuration file"
                    fi
                else
                    colorEcho  ${RED} "nginx failed to start!!!###Please check your nginx process###"
                fi
            else
                colorEcho  ${YELLOW} "Please manually copy the /opt/jonnyan404/mrdoc_nginx_jonnyan404.conf file to your nginx configuration"
            fi
            colorEcho  ${GREEN}  "$(cat /opt/jonnyan404/pwdinfo.log),Password is saved in /opt/jonnyan404/pwdinfo.log"
        fi
    fi
}

main
