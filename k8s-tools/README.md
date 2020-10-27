**1.k8s网络诊断工具**
```
1.Kubernetes 问题定位技巧:容器内抓包
- 提供实用的脚本一键进入容器网络命名空间(netns)，使用node宿主机上的tcpdump进行抓包。
```
**2.使用场景-发现某个服务网络不通**
```
操作流程
- 最好将其副本数调为1，并找到这个副本pod所在节点和pod名称:kubectl scale deployment --replicas=1 service -n namespaces   #####缩容和升级###############
- 登录pod 所在ip node节点,执行该脚本进入容器网络命名空间
- 执行宿主机上的ip a或ifconfig来查看容器的网卡,执行netstat -tunlp查看当前容器监听了哪些端口,再通过tcpdump 抓包
- tcpdump 命令:tcpdump -i eth0 -w test.pcap port 80 #抓取容器网卡eth0 监听端口为:80 端口
- 将抓下来的包下载到本地使用 wireshark 
```
3.**脚本原理*
```
我们解释下步骤二中用到的脚本的原理
查看指定 pod 运行的容器 ID
kubectl describe pod <pod> -n mservice
获得容器进程的 pid
docker inspect -f {{.State.Pid}} <container>
进入该容器的 network namespace
nsenter -n --target <PID>
依赖宿主机的命令：kubectl, docker, nsenter, grep, head, sed
``
