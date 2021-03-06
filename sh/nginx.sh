#!/bin/bash
a=$(cat /proc/cpuinfo | grep 'model name'| wc -l)
ngstable=1.12.2
zlibstable=1.2.11
curlstable=8.41

if [ ! -e '/usr/bin/wget' ]; then
yum -y install wget
fi
Bit=$(getconf LONG_BIT)

#版本
if  [ -n "$(grep ' 7\.' /etc/redhat-release)" ] ;then
CentOS_RHEL_version=7
elif
[ -n "$(grep ' 6\.' /etc/redhat-release)" ]; then
CentOS_RHEL_version=6
fi

yum -y remove httpd httpd* nginx
yum -y install gcc gcc-c++ make vim screen python git
cd ~
#git clone https://github.com/cuber/ngx_http_google_filter_module
#git clone https://github.com/yaoweibin/ngx_http_substitutions_filter_module

#zlib 非必要编译安装
cd ~
yum -y install zlib-devel
wget http://zlib.net/zlib-${zlibstable}.tar.gz
tar -zxvf zlib-${zlibstable}.tar.gz
cd zlib-${zlibstable}
./configure  --prefix=/usr/local/zlib
make -j$a
make install
echo "/usr/local/zlib/lib" > /etc/ld.so.conf.d/zlib.conf
ldconfig

yum -y install libtool
#具体作用不明
#cd ~
#wget http://ftpmirror.gnu.org/libtool/libtool-2.4.6.tar.gz


#pcre 非必要编译安装
cd ~
wget https://ftp.pcre.org/pub/pcre/pcre-${curlstable}.tar.gz
tar -zxvf pcre-${curlstable}.tar.gz
cd pcre-${curlstable}
./configure  --prefix=/usr/local/pcre/
make -j$a
make install
/root/pcre-${curlstable}/libtool /usr/local/pcre/lib/
echo "/usr/local/pcre/lib/" > /etc/ld.so.conf.d/pcre.conf
ldconfig -v

#openssl
cd ~
wget -4 --no-check-certificate https://www.openssl.org/source/openssl-1.1.0-latest.tar.gz
tar -zxvf openssl-1.1.0-latest.tar.gz
mv openssl-1.1.0? openssl-1.1.0-latest
cd ~

wget -4 http://nginx.org/download/nginx-${ngstable}.tar.gz
tar -zxvf nginx-${ngstable}.tar.gz

#Copy NGINX manual page to /usr/share/man/man8:
yum -y install gzip man
cp -f ~/nginx-${ngstable}/man/nginx.8 /usr/share/man/man8
gzip /usr/share/man/man8/nginx.8

cd ~/nginx-${ngstable}
./configure --prefix=/usr/local/nginx --user=www --group=www \
--build=CentOS \
--modules-path=/usr/local/nginx/modules \
--with-openssl=/root/openssl-1.1.0-latest \
--with-pcre=/root/pcre-${curlstable} \
--with-zlib=/root/zlib-${zlibstable} \
--with-http_stub_status_module \
--with-http_secure_link_module \
--with-threads \
--with-file-aio \
--with-http_v2_module \
--with-http_ssl_module \
--with-http_gzip_static_module \
--with-http_gunzip_module \
--with-http_realip_module \
--with-http_flv_module \
--with-http_mp4_module \
--with-http_sub_module \
--with-http_dav_module \
--with-stream \
--with-stream=dynamic \
--with-stream_ssl_module \
--with-stream_realip_module \
--with-stream_ssl_preread_module
make -j$a
make install

#--with-ipv6 废弃的参数
#--add-module=/root/ngx_http_google_filter_module
#--add-module=/root/ngx_http_substitutions_filter_module
#--modules-path=PATH                set modules path
#--add-dynamic-module=PATH          enable dynamic external module
#  + using PCRE library: /root/pcre
#  + using OpenSSL library: /root/openssl
#  + using zlib library: /root/zlib


if [ ! -e '/usr/local/nginx/sbin/nginx' ]; then
echo -e "\033[31m Install nginx error ... \033[0m \n"
exit 1
fi

#检测web用户是否存在
    id -u www >/dev/null 2>&1
    [ $? -ne 0 ] && useradd -M -s /sbin/nologin www;
chown www.www -R /usr/local/nginx;

#开始判断CentOS版本
if [ $CentOS_RHEL_version -eq 6 ];then
#wget -O /etc/init.d/nginx http://file.asuhu.com/so/nginx_centos6

cat > /etc/init.d/nginx << "EOF"
#!/bin/sh
#
# nginx - this script starts and stops the nginx daemon
#
# chkconfig:   - 85 15
# description:  Nginx is an HTTP(S) server, HTTP(S) reverse \
#               proxy and IMAP/POP3 proxy server
# processname: nginx
# config:      /usr/local/nginx/conf/nginx.conf
# pidfile:     /var/run/nginx.pid

# Source function library.
. /etc/rc.d/init.d/functions

# Source networking configuration.
. /etc/sysconfig/network

# Check that networking is up.
[ "$NETWORKING" = "no" ] && exit 0

nginx="/usr/local/nginx/sbin/nginx"
prog=$(basename $nginx)

NGINX_CONF_FILE="/usr/local/nginx/conf/nginx.conf"

[ -f /etc/sysconfig/nginx ] && . /etc/sysconfig/nginx

lockfile=/var/lock/subsys/nginx

make_dirs() {
   # make required directories
   user=`$nginx -V 2>&1 | grep "configure arguments:" | sed 's/[^*]*--user=\([^ ]*\).*/\1/g' -`
   if [ -z "`grep $user /etc/passwd`" ]; then
       useradd -M -s /bin/nologin $user
   fi
   options=`$nginx -V 2>&1 | grep 'configure arguments:'`
   for opt in $options; do
       if [ `echo $opt | grep '.*-temp-path'` ]; then
           value=`echo $opt | cut -d "=" -f 2`
           if [ ! -d "$value" ]; then
               # echo "creating" $value
               mkdir -p $value && chown -R $user $value
           fi
       fi
   done
}

start() {
    [ -x $nginx ] || exit 5
    [ -f $NGINX_CONF_FILE ] || exit 6
    make_dirs
    echo -n $"Starting $prog: "
    daemon $nginx -c $NGINX_CONF_FILE
    retval=$?
    echo
    [ $retval -eq 0 ] && touch $lockfile
    return $retval
}

stop() {
    echo -n $"Stopping $prog: "
    killproc $prog -QUIT
    retval=$?
    echo
    [ $retval -eq 0 ] && rm -f $lockfile
    return $retval
}

restart() {
    configtest || return $?
    stop
    sleep 3
    start
}

reload() {
    configtest || return $?
    echo -n $"Reloading $prog: "
    killproc $nginx -HUP
    RETVAL=$?
    echo
}

force_reload() {
    restart
}

configtest() {
  $nginx -t -c $NGINX_CONF_FILE
}

rh_status() {
    status $prog
}

rh_status_q() {
    rh_status >/dev/null 2>&1
}

case "$1" in
    start)
        rh_status_q && exit 0
        $1
        ;;
    stop)
        rh_status_q || exit 0
        $1
        ;;
    restart|configtest)
        $1
        ;;
    reload)
        rh_status_q || exit 7
        $1
        ;;
    force-reload)
        force_reload
        ;;
    status)
        rh_status
        ;;
    condrestart|try-restart)
        rh_status_q || exit 0
            ;;
    *)
        echo $"Usage: $0 {start|stop|status|restart|condrestart|try-restart|reload|force-reload|configtest}"
        exit 2
esac
EOF

#赋予权限
chmod +x /etc/init.d/nginx;

#开机启动
chkconfig --add nginx; chkconfig nginx on;

#防火墙设置
service iptables start;chkconfig iptables on;
iptables -I INPUT -p tcp -m multiport --dport 80,443,8080,8081,3306 -j ACCEPT;
service iptables save;service iptables restart;

#################################################
#最新zlib，未使用
#if [ $Bit -eq 64 ]; then
#ln -sf  /usr/local/zlib/lib/libz.so.${zlibstable} /lib64/libz.so.1.2.3
# elif [ $Bit -eq 32 ];then
#ln -sf /usr/local/zlib/lib/libz.so.${zlibstable} /lib/libz.so.1.2.3
#fi
#################################################

#禁用firewalld，启用iptables
elif [ $CentOS_RHEL_version -eq 7 ];then
 if systemctl status firewalld;then
systemctl stop firewalld;systemctl disable firewalld;systemctl mask firewalld
echo off firewalld
else
systemctl mask firewalld
 fi
#systemctl is-enabled firewalld
#systemctl is-active firewalld

yum install iptables-services iptables-devel -y
systemctl enable iptables
iptables -F
iptables -I INPUT -p tcp -m multiport --dport 80,443,8080,8081,3306 -j ACCEPT;
service iptables save;service iptables restart;
###################################################
cat > /usr/lib/systemd/system/nginx.service << EOF
[Unit]
Description=nginx - high performance web server
Documentation=http://nginx.org/en/docs/
After=network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
PIDFile=/usr/local/nginx/logs/nginx.pid
ExecStartPre=/usr/local/nginx/sbin/nginx -t -c /usr/local/nginx/conf/nginx.conf
ExecStart=/usr/local/nginx/sbin/nginx -c /usr/local/nginx/conf/nginx.conf
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
chmod +x /usr/lib/systemd/system/nginx.service
systemctl enable nginx.service
systemctl start nginx.service

fi
#CentOS 6 7 判断结束
###########################################################

#环境变量设置
echo 'export PATH=/usr/local/nginx/sbin:$PATH'>>/etc/profile;
source /etc/profile;#重启生效

service nginx restart;
#ldd $(which nginx)


#日志轮训，需要配合crontab和logrotate
#安装crond Cronie (sys-process/cronie) is a fork of vixie-cron done by Fedora. Because of it being a fork it has the same feature set the original vixie-cron provides
if ! which crond >/dev/null 2>&1;then yum install cronie -y; fi

yum -y install logrotate
if [ $CentOS_RHEL_version -eq 6 ];then
cat > /etc/logrotate.d/nginx << EOF
/home/wwwlogs/*log {
daily
rotate 30
missingok
dateext
notifempty
sharedscripts
postrotate
    [ -e /usr/local/nginx/logs/nginx.pid ] && kill -USR1 \`cat /usr/local/nginx/logs/nginx.pid\`
endscript
}
EOF
else
cat > /etc/logrotate.d/nginx << EOF
/home/wwwlogs/*log {
su www www
daily
rotate 30
missingok
dateext
notifempty
sharedscripts
postrotate
    [ -e /usr/local/nginx/logs/nginx.pid ] && kill -USR1 \`cat /usr/local/nginx/logs/nginx.pid\`
endscript
}
EOF
fi

#清理nginx pcre zlib
cd ~
rm -rf nginx-${ngstable}.tar.gz
rm -rf openssl-1.1.0-latest.tar.gz
rm -rf pcre-${curlstable}.tar.gz
rm -rf zlib-${zlibstable}.tar.gz
/usr/local/nginx/sbin/nginx -V