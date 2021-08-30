#!/bin/env bash
initPackage(){
#关闭系统防火墙和epel扩展源
yum install epel-release
#关闭selinx 
setenforce 0 && sed -i 's/enforcing/disabled/g' /etc/sysconfig/selinux
sed -i 's/enforcing/disabled/g' /etc/selinux/config

#关闭防火墙
systemctl stop firewalld 
#是清空指定某个chains 内所有的rule设定
iptables -F 
}

configDhcp(){
yum install dhcp-4.2** -y 
echo -e "033[dhcp 配置文件生成... \033[0m" 
ip=$(hostname -i)
if [ -n $ip ]
then
str=$(echo $ip|cut -d. -f 1,2,3)
cat > /etc/dhcp/dhcpd.conf <<EOF 
default-lease-time 2592000;
preferred-lifetime 604800;
option domain-name "pxe.org";
option domain-name-servers 114.114.114.114,8.8.8.8;
option dhcp-renewal-time 3600;
option dhcp-rebinding-time 7200;
subnet $str.0 netmask 255.255.255.0 {
range  $str.220 $str.240;
option routers $str.254;
next-server $ip;
filename "pxelinux.0"; 
}
EOF
else
   echo -e "033[dhcp 配置文件生成... \033[0m"   
fi
}


configTftp(){
yum -y install xinetd tftp-server  xinetd syslinux
echo -e "033[xftp 生成配置文件... \033[0m"   
cat > /etc/xinetd.d/tftp <<EOF
# default: off
# description: The tftp server serves files using the trivial file transfer \
#   protocol.  The tftp protocol is often used to boot diskless \
#   workstations, download configuration files to network-aware printers, \
#   and to start the installation process for some operating systems.
service tftp
{
    socket_type     = dgram
    protocol        = udp
    wait            = yes
    user            = root
    server          = /usr/sbin/in.tftpd
    server_args     = -s /var/lib/tftpboot -c 
    disable         = no
    per_source      = 11
    cps         = 100 2
    flags           = IPv4
}
EOF
cp /usr/share/syslinux/pxelinux.0 /var/lib/tftpboot/
}

configNginx(){
yum install nginx -y  rsync
nginxPathDir="/etc/nginx/conf.d"
if [ -d $nginxPathDir ]
then
ip=$(hostname -i)
echo -e "033[nginx 生成配置文件... \033[0m" 

cat > /etc/nginx/conf.d/auto-kickstart.conf <<EOF    
    server {
        listen       80;
        server_name  $ip;
        location / {
            autoindex on;        #打开目录浏览功能
            autoindex_exact_size off;  # off：以可读的方式显示文件大小
            autoindex_localtime on; # on、off：是否以服务器的文件时间作为显示的时间
            charset utf-8,gbk; #展示中文文件名
            root   /usr/local/centos7-os;  #将centos7的镜像放入此位置
            index  index.html index.htm;
        }
      }
EOF
   mkdir -p /usr/local/centos7-os  
   mount /dev/cdrom  /mnt
   echo -e "033  开始同步ios镜像文件,请耐心等待3分钟左右... \033[0m"   
   rsync -avPg /mnt/ /usr/local/centos7-os/
   cp -a  /usr/local/centos7-os/isolinux/* /var/lib/tftpboot/  
   mkdir -p /var/lib/tftpboot/pxelinux.cfg 
   cp  /usr/local/centos7-os/isolinux/isolinux.cfg  /var/lib/tftpboot/pxelinux.cfg/default
else
  echo -e "033 nginx 没有安装程,请检查... \033[0m"   
fi 
}

pxeClient(){
ip=$(hostname -i)
mkdir -p /var/lib/tftpboot/pxelinux.cfg
cat > /var/lib/tftpboot/pxelinux.cfg/default <<EOF 
default sk
promet 0       
timeout 600
display boot.msg 
menu clear
menu background splash.png
menu title CentOS 7
menu vshift 8
menu rows 18
menu margin 8
menu helpmsgrow 15
menu tabmsgrow 13
menu color border * #00000000 #00000000 none
menu color sel 0 #ffffffff #00000000 none
menu color title 0 #ff7ba3d0 #00000000 none
menu color tabmsg 0 #ff3a6496 #00000000 none
menu color unsel 0 #84b8ffff #00000000 none
menu color hotsel 0 #84b8ffff #00000000 none
menu color hotkey 0 #ffffffff #00000000 none
menu color help 0 #ffffffff #00000000 none
menu color scrollbar 0 #ffffffff #ff355594 none
menu color timeout 0 #ffffffff #00000000 none
menu color timeout_msg 0 #ffffffff #00000000 none
menu color cmdmark 0 #84b8ffff #00000000 none
menu color cmdline 0 #ffffffff #00000000 none
menu tabmsg Press Tab for full configuration options on menu items.
menu separator # insert an empty line
menu separator # insert an empty line
label sk
  menu default 
  kernel vmlinuz
  #append initrd=initrd.img inst.stage2=hd:LABEL=CentOS\x207\x20x86_64 quiet
  append initrd=initrd.img inst.ks=http://$ip/centos7-ks/centos7-ks.cfg devfs=nomount nofb 
label check
  menu label Test this ^media & install CentOS Linux 7
  menu default
  kernel vmlinuz
  append initrd=initrd.img inst.stage2=hd:LABEL=CentOS\x207\x20x86_64 rd.live.check quiet
menu separator # insert an empty line
menu begin ^Troubleshooting
  menu title Troubleshooting
label vesa
  menu indent count 5
  menu label Install CentOS Linux 7 in ^basic graphics mode
  text help
    Try this option out if you're having trouble installing
    CentOS Linux 7.
  endtext
  kernel vmlinuz
  append initrd=initrd.img inst.stage2=hd:LABEL=CentOS\x207\x20x86_64 xdriver=vesa nomodeset quiet
label rescue
  menu indent count 5
  menu label ^Rescue a CentOS Linux system
  text help
    If the system will not boot, this lets you access files
    and edit config files to try to get it booting again.
  endtext
  kernel vmlinuz
  append initrd=initrd.img inst.stage2=hd:LABEL=CentOS\x207\x20x86_64 rescue quiet
label memtest
  menu label Run a ^memory test
  text help
    If your system is having issues, a problem with your
    system's memory may be the cause. Use this utility to
    see if the memory is working correctly.
  endtext
  kernel memtest
menu separator # insert an empty line
label local
  menu label Boot from ^local drive
  localboot 0xffff
menu separator # insert an empty line
menu separator # insert an empty line
label returntomain
  menu label Return to ^main menu
  menu exit
menu end
EOF
chmod 755 /var/lib/tftpboot/pxelinux.cfg/default
echo -e "033 生成pxelinxu.cfg 默认配置... \033[0m" 
}


PxelinuxDefault(){
ip=$(hostname -i)
mkdir /usr/local/centos7-os/centos7-ks/ -p 
cd   /usr/local/centos7-os/centos7-ks/
cat > centos7-ks.cfg <<EOF
#version=RHEL7
#Install OS instead of upgrade  #告知安装程序，这是一次全新安装，而不是升级
install
# System authorization information

# Use Web installation  #通过http下载安装镜像  #这里指定错误，就会获取不到镜像文件
url --url http://$ip 
text
lang en_US.UTF-8
keyboard us
zerombr
bootloader --location=mbr --driveorder=sda --append="crashkernel=auto rhgb quiet"
network --bootproto=dhcp --device=eth0 --onboot=yes --noipv6 --hostname=CentOS7
timezone --utc Asia/Shanghai
authconfig --enableshadow --passalgo=sha512
rootpw --iscrypted \$6\$4/LtE7Epu9PGKS7B\$FkjCppxcjDxfYJ6RAFU52W0JzPWYDjQmyt2sa8lydljECLrhGH6YwtKBNQtXqF59bDs2CSfSiFPLEzgy2EfPz0
clearpart --all --initlabel
part /boot --fstype=xfs --asprimary --size=200
part swap --size=768
part / --fstype=xfs --grow --asprimary --size=200
firstboot --disable
selinux --disabled
firewall --disabled
logging --level=info
reboot
%packages
@base
@compat-libraries
@debugging
@development
tree
nmap
sysstat
lrzsz
dos2unix
telnet
%end
EOF
echo -e "\033[32m 生成client动应答ks文件: \033[0m"
}

allServiceManegr(){
systemctl restart dhcpd 
systemctl enable dhcpd
systemctl restart xinetd
systemctl enable xinetd
systemctl restart nginx
systemctl enable nginx
systemctl disable NetworkManager
systemctl stop NetworkManager
}


main() {
    initPackage
    configDhcp
    configTftp
    configNginx 
    PxelinuxDefault
    pxeClient
    allServiceManegr
}

case $1 in 
    "init")
        initPackage
        ;;
    "indhcp")
        configDhcp
        ;;
    "intftp")
        configTftp 
        ;;
    "confginx")
        configNginx
        ;;
    "confpxelinux")
        PxelinuxDefault
        ;;
    "pxclient")
        pxeClient
       ;;
    "allreservice") 
       allServiceManegr
       ;;   
    "all")
        main
        ;;
    *)
       
        echo -e "\033[32m 请先准备系统iso系统镜像文件: \033[0m"
        echo -e "\033[32m 部署参数如下: \033[0m"
        echo -e "\033[32m init \033[0m 系统环境调整"
        echo -e "\033[32m indhcp \033[0m 安装和配置dhcp服务"
        echo -e "\033[32m intftp \033[0m 安装和配置intftp服务"
        echo -e "\033[32m confginx \033[0m 安装和配置nginx服务"
        echo -e "\033[32m confpxelinux \033[0m 配置pxelinux"
        echo -e "\033[32m pxclient \033[0m 配置pxclient"
        echo -e "\033[32m allreservice \033[0m 启动全部服务"
        echo -e "\033[32m all \033[0m 上述所有"
        ;;
esac

