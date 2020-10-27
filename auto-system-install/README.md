**Centos7 系统自动化系统安装脚本**

***1.执行脚本前置条件***

  - 需要有一台已经部署好操作系统且具备能正常上网条件的VM虚拟机或者物理机；
  - 网络正常相互访问和支持SSH远程登陆访问；
  - 准备一个服务器版本系统镜像并挂载到该机器,也可以通过网络在线获取使用,本人不建议依赖网络带宽安装过程较慢；

***2.温馨提示***
```
1.系统镜像获取地址: http://mirrors.aliyun.com/centos/
2. Kickstart 部署学习地址:https://access.redhat.com/documentation/zh-cn/red_hat_enterprise_linux/7/html/installation_guide/index
```

***3.脚本功能介绍***
```
通过网络介质和预启动执行环境（Preboot eXecution Environment，PXE）也被称为预执行环境，提供了一种使用网络接口（Network Interface）启动计算机的机制。这种机制让计算机的启动可以不依赖本地数据存储设备（如硬盘）或本地已安装的操作系统,适用于大规模安装服务器运行系统并快速部署预安装应用运行环境等场景.
```
***4.脚本内容概述**
```
- 部署DHCP(动态主机配置协议)是一个局域网的网络协议.安装服务器控制一段IP地址范围,客户端登录服务器时可以自动获得服务器分配的IP地址和子网掩码。
- 部署tftp TFTP(Trivial File Transfer Protocol,简单文件传输协议）客户机获取网络信息且携带p指定tftp文件名去tftp服务根路径找pxelinux.0启动文件
- 部署nginx(高性能的HTTP和反向代理web服务器)可以通过HTTP方式获取指定ks.cfg文件存储服务器和安装需要系统软件包等.
- 启动DHCP和TFTP和NGINX等服务
```

***5.使用说明***
```
[root@auto-system-install]# bash auto-system-kickstart.sh  all #安装全部包含服务
 请先准备系统iso系统镜像文件: 
 部署参数如下: 
 init  系统环境调整
 indhcp  安装和配置dhcp服务
 intftp  安装和配置intftp服务
 confginx  安装和配置nginx服务
 confpxelinux  配置pxelinux
 pxclient  配置pxclient
 allreservice  启动全部服务
 all  上述所有
```

