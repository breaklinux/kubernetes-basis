#!/bin/env bash

update_yum() {
    echo -e "\033[32m 全量升级yum源... \033[0m"
    yum -y update
}

change_repo() {
    echo -e "\033[32m 切换Repo仓库... \033[0m"
    rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
    rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-3.el7.elrepo.noarch.rpm
}

list_kernel() {
    echo -e "\033[32m 查看所有kernel新版本... \033[0m"
    yum --disablerepo="*" --enablerepo="elrepo-kernel" list available
}

install_kernel() {
    echo -e "\033[32m 安装kernel-ml 5.6.11-1.版本... \033[0m"
    yum -y --enablerepo=elrepo-kernel install kernel-ml 
}
#查看可用内核
list_kernels() {
    echo -e "\033[32m 查看机器所有可用kernel版本... \033[0m"
    awk -F\' '$1=="menuentry " {print i++ " : " $2}' /etc/grub2.cfg
}






#设置内核启动
set_grub() {
    echo -e "\033[32m 设置grub启动内核... \033[0m"

    grub2-set-default 0

cat > /etc/default/grub << EOF
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="$(sed 's, release .*$,,g' /etc/system-release)"
GRUB_DEFAULT=0
GRUB_DISABLE_SUBMENU=true
GRUB_TERMINAL_OUTPUT="console"
GRUB_CMDLINE_LINUX="crashkernel=auto rd.lvm.lv=vg_root/lv_root rhgb quiet"
GRUB_DISABLE_RECOVERY="true"
EOF
}

#生成grub文件
build_grub() {
    echo -e "\033[32m 生成grub文件... \033[0m"
    grub2-mkconfig -o /boot/grub2/grub.cfg
}

reboot_system() {
    echo -e "\033[32m 重启机器... \033[0m"
    reboot
}

#查看内核版本
list_kernel_rpm() {
    echo -e "\033[32m 查看已安装kernel rpm包 ... \033[0m"
    rpm -qa | grep kernel
}

#卸载旧版本内核
uninstall_old_kernel(){
    echo -e "\033[32m 卸载旧版本kernel和相关tools工具 ... \033[0m"
    yum remove -y kernel-3.10.0-327.el7.x86_64 kernel-3.10.0-1062.18.1.el7.x86_64 kernel-tools-3.10.0-1062.18.1.el7.x86_64 kernel-tools-libs-3.10.0-1062.18.1.el7.x86_64
}
#安装utils工具
install_yum_utils() {
    echo -e "\033[32m 安装utils工具... \033[0m"
    yum install -y yum-utils
}
#删除旧版本
uninstall_old_packages() {
    uninstall_old_kernel
    install_yum_utils
    echo -e "\033[32m 删除旧版本包... \033[0m"
    package-cleanup --oldkernels -y
}

#关闭相关服务
stop_service_init_service() {
    echo -e "\033[32m 关闭防火墙... \033[0m"
    systemctl stop firewalld
    systemctl disable firewalld

    echo -e "\033[32m 关闭swap... \033[0m"
    swapoff -a
    sed -i 's/.*swap.*/#&/' /etc/fstab

    echo -e "\033[32m 关闭selinux... \033[0m"
    setenforce  0
    sed -i "s/^SELINUX=enforcing/SELINUX=disabled/g" /etc/sysconfig/selinux
    sed -i "s/^SELINUX=enforcing/SELINUX=disabled/g" /etc/selinux/config
    sed -i "s/^SELINUX=permissive/SELINUX=disabled/g" /etc/sysconfig/selinux
    sed -i "s/^SELINUX=permissive/SELINUX=disabled/g" /etc/selinux/config
    
    echo -e "\033[32m 启动bpf功能支持cilium网络插件... \033[0m"
    mount /sys/fs/bpf    
    sed  -i '$a bpffs /sys/fs/bpf   bpf  defaults 0 0' /etc/fstab
   
    echo -e "\033[32m init kubernetes base service... \033[0m"
    modprobe br_netfilter
cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
    sysctl -p /etc/sysctl.d/k8s.conf
    ls /proc/sys/net/bridge

    echo -e "\033[32m 配置kubernetes yum源... \033[0m"
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
    echo -e "\033[32m 安装相关基础依赖包... \033[0m"
    yum install -y epel-release
    yum install -y yum-utils device-mapper-persistent-data lvm2 net-tools conntrack-tools wget vim  ntpdate libseccomp libtool-ltdl

    echo -e "\033[32m 配置时间同步... \033[0m"
    systemctl enable ntpdate.service
    echo '*/30 * * * * /usr/sbin/ntpdate time7.aliyun.com >/dev/null 2>&1' > /tmp/kubernetes_crontab.tmp
    crontab /tmp/kubernetes_crontab.tmp
    systemctl start ntpdate.service

    echo -e "\033[32m 修改相关limits限制配置... \033[0m"
    echo -e "\033[32m * soft nofile 65536" >> /etc/security/limits.conf
    echo -e "\033[32m * hard nofile 65536" >> /etc/security/limits.conf
    echo -e "\033[32m * soft nproc 65536"  >> /etc/security/limits.conf
    echo -e "\033[32m * hard nproc 65536"  >> /etc/security/limits.conf
    echo -e "\033[32m * soft  memlock  unlimited"  >> /etc/security/limits.conf
    echo -e "\033[32m * hard memlock  unlimited"  >> /etc/security/limits.conf

}



main() {
    update_yum
    change_repo
    list_kernel
    install_kernel
    list_kernels
    set_grub
    build_grub
}


case $1 in 
    "update")
        update_yum
        ;;
    "change")
        change_repo
        ;;
    "list")
        list_kernel
        ;;
    "install_kernel")
        install_kernel
        list_kernels
        ;;
    "set_grub")
        set_grub
        build_grub
        ;;
    "reboot")
        reboot_system
        ;;
    "kernel_rpm")
        list_kernel_rpm
        ;;
    "uninstall_kernel")
        uninstall_old_packages
        ;;
    "init_k8s_base_service")
        stop_service_init_service
        ;;
    "all")
        main
        ;;
    *)
        echo -e "\033[32m 参数如下: \033[0m"
        echo -e "\033[32m update \033[0m 升级yum"
        echo -e "\033[32m change \033[0m 修改yum repo"
        echo -e "\033[32m list \033[0m 查看可安装kernel版本"
        echo -e "\033[32m install_kernel \033[0m 安装最新版本kernel"
        echo -e "\033[32m set_grub \033[0m 设置grub启动"
        echo -e "\033[32m reboot  \033[0m 重启系统"
        echo -e "\033[32m kernel_rpm \033[0m 查看所有已安装kernel rpm"
        echo -e "\033[32m uninstall_kernel \033[0m 卸载老版本包"
        echo -e "\033[32m init_k8s_base_service \033[0m 初始化k8s相关依赖(关闭防火墙 swap selinux),安装依赖 初始化yum源 修改limits配置等"
        echo -e "\033[32m all \033[0m 上述所有"
        ;;
esac
