**1.通过ansible进行系统环境准备**

| 主机IP规划	 | 主机名规划	 | 用途 
| ------ | ------ |------ |
| 192.168.1.12	 | ansible-matser	 |ansible运维控制机
| 192.168.2.114 | k8s-master-1-58.114    |k8s-master01 控制节点-1 
| 192.168.3.117 | k8s-master-2-58.117	 |k8s-master01 控制节点-2
| 192.168.4.116 | k8s-master-3-58.116	 |k8s-master01 控制节点-3
| 192.168.5.119 | k8s-node-1-58.119     |k8s-node01 工作节点-1   


| 主机IP规划	 | 主机名规划	 | 角色  | 用途 
| ------ | ------ |------ |------ |
| 192.168.31.200	 | haproxy-1-31-200	   |none |harproxy-api-server 代理
| 192.168.31.201  | k8s-master-1-31.201 |master|k8s-master01 控制节点-1 
| 192.168.31.202  | k8s-master-2-31.202	|master|k8s-master01 控制节点-2
| 192.168.31.203  | k8s-master-3-31.203	|master|k8s-master01 控制节点-3
| 192.168.31.204  | k8s-node-1-31-204   |work |k8s-node01 工作节点-1   
| 192.168.31.205  | k8s-node-1-31-205   |work |k8s-node02 工作节点-1   




**2.登陆机器配置inventory主机**
```
cat k8s-init-inventory.txt
[k8s-dev]
 192.168.1.114 host_name=k8s-master-1-58.114  sshkey_role=ras 
 192.168.2.117 host_name=k8s-master-2-58.117  sshkey_role=pub 
 192.168.3.116 host_name=k8s-master-3-58.116  sshkey_role=pub 
 192.168.4.119 host_name=k8s-node-1-58.119   sshkey_role=pub 
```

**3.编写初始化主机名称playbook**

```
配置ssh密钥认证和获取初始化脚本

[ops@ansible-master tmp]$ cat k8s_init.yam 

- hosts: k8s-dev
  user: ops
  gather_facts: true
  tasks:
    - name: 规划主机名
      hostname: 'name={{ host_name }}'
    - name: 新增hosts解析信息
      lineinfile:
        dest: /etc/hosts
        line: "{{ ansible_all_ipv4_addresses[0] }} {{ host_name }}"
    - name: 设置允许root 用户ssh-key登陆
      shell: sed -i "s/^PermitRootLogin no/PermitRootLogin yes/g" /etc/ssh/sshd_config

    - name: ssh连接是否需要yes配置
      shell: sed -i "1a StrictHostKeyChecking no" /etc/ssh/ssh_config

    - name: 加载生效ssh服务配置
      service: name=sshd state=restarted

    - debug:
          msg: "下载ssh私钥文件"
      when: sshkey_role == "ras"
    - name: 获取私钥文件和下载系统初始化脚本
      shell: curl http://ops.com:9090/scripts/k8s/add_k8s_ras.sh|sh &&  wget -P /tmp/ http://k8s.com/admin/init_kubernetes/k8s-init-system.sh && wget -P /tmp/ http://k8s.com/admin/init_kubernetes/k8s-install.sh
      register: get_k8s_master_init_script
      ignore_errors: True


    - debug:
          msg: "下载公钥文件"
      when: sshkey_role == "pub"
    - name: 获取公钥文件,下载系统初始化脚本和k8s安装脚本
      shell: curl http://ops.com:9090/scripts/k8s/add_pub.k8s.sh|sh && wget -P /tmp/ http://k8s.com/admin/init_kubernetes/k8s-init-system.sh
      register: get_k8s_node_init_script
      ignore_errors: True

    - name: "开始准备k8s基础环境,执行等待6分钟"
      when: get_k8s_master_init_script and get_k8s_node_init_script
      shell: /bin/bash /tmp/k8s-init-system.sh all

    - name: "重启k8s机器,30秒后启动"
      shell: reboot      
  
```
重启系统后操作
```
---
[ops@ansible-master tmp]$# k8s-init-reboot-system.y
- hosts: k8s-dev
  user: ops
  tasks:
    - ping:
    - name: 卸载系统旧版本内核
      shell: /bin/bash /tmp/k8s-init-system.sh uninstall_kernel
      
    - name: 配置安装k8s-admin准备环境
      shell: /bin/bash /tmp/k8s-init-system.sh init_k8s_base_service
```





**4.测试ansible机器联通性**

```
[ops@ansible-master tmp]$ ansible -i k8s-init-inventory.txt k8s-dev -m ping 
192.168.1.116 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
192.168.2.117 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
192.168.3.114 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
192.168.4.119 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

**5.检查playbook 语法检查**

```
出现playbook文件名正常,无其他异常信息
[ops@ansible-master tmp]$ ansible-playbook k8s_init.yam   --syntax-check
playbook: k8s_init.yam
```
**6.执行playbook**

```
[ops@ansible-master tmp]$ ansible-playbook  -i k8s-init-inventory.txt k8s_init.yam -b 
PLAY [k8s-dev] *************************************************************************

ok: [192.168.1.117]
ok: [192.168.2.114]
ok: [192.168.3.116]
ok: [192.168.4.119]

TASK [规划主机名] **********************************************************************
ok: [192.168.1.117]
ok: [192.168.2.119]
ok: [192.168.3.114]
ok: [192.168.4.116]

TASK [新增hosts解析信息] ****************************************************************************************
ok: [192.168.1.117]
ok: [192.168.2.119]
ok: [192.168.3.114]
ok: [192.168.4.116]

TASK [设置允许root 用户ssh-key登陆] ****************************************************************************************
changed: [192.168.1.117]
changed: [192.168.2.119]
changed: [192.168.3.114]
changed: [192.168.4.116]

TASK [ssh连接是否需要yes配置] ***************************************************************************************
changed: [192.168.1.114]
changed: [192.168.2.117]
changed: [192.168.3.116]
changed: [192.168.5.119]

TASK [加载生效ssh服务配置] ****************************************************************************************
changed: [192.168.1.119]
changed: [192.168.1.117]
changed: [192.168.3.114]
changed: [192.168.4.116]

TASK [debug] ***************************************************************************
skipping: [192.168.1.117]
skipping: [192.168.2.116]
ok: [192.168.3.114] => {
    "msg": "下载ssh私钥文件"
}
skipping: [192.168.1.119]
TASK [获取私钥文件] *****************************************************************************************************************
changed: [192.168.1.117]
changed: [192.168.2.114]
changed: [192.168.3.116]
changed: [192.168.4.119]

TASK [debug] ******************************************************************************************************************
skipping: [192.168.1.114]
ok: [192.168.1.117] => {
    "msg": "下载公钥文件"
}
ok: [192.168.2.116] => {
    "msg": "下载公钥文件"
}
ok: [192.168.3.119] => {
    "msg": "下载公钥文件"
}

TASK [获取公钥文件] ********************************************************************
changed: [192.168.1.117]
changed: [192.168.2.116]
changed: [192.168.4.114]
changed: [192.168.3.119]

PLAY RECAP ********************************************************************************************************************
192.168.1.114             : ok=9    changed=5    unreachable=0    failed=0   
192.168.2.116             : ok=9    changed=5    unreachable=0    failed=0   
192.168.3.117             : ok=9    changed=5    unreachable=0    failed=0   
192.168.4.119             : ok=9    changed=5    unreachable=0    failed=0   
```


**7.登陆master01 部署相关组件和etcd**

```
---
[root@k8s-master-1 tmp]# sh k8s-install.sh
 参数如下: 
 install_etcd  安装etcd 后面跟节点ip
 install_docker  安装docker 后面跟ip
 install_kube  安装kubenetes相关 后面跟ip
 all  一键kubernetes安装 后面跟 matser_ip1 matser_ip2 matser_ip3 node_ip
```


**8.开始安装组件和etcd以及初始化**

```
---
安装etcd
[root@k8s-master-1 tmp]#sh k8s-install.sh  install_etcd 192.168.1.114 192.168.2.117 192.168.3.116 192.168.4.119

安装docker服务
[root@k8s-master-1 tmp]#sh k8s-install.sh  install_docker 192.168.1.114 192.168.2.117 192.168.3.116 192.168.4.119

安装kube-admin组件
[root@k8s-master-1 tmp]#sh k8s-install.sh  install_kube 192.168.1.114 192.168.2.117 192.168.3.116 192.168.5.119

初始化kube-admin 
[root@k8s-master-1 tmp]# sh k8s-install.sh init_kubernetes 192.168.1.114 192.168.2.117 192.168.3.116 192.168.4.119

```
