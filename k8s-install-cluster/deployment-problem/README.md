**1.设置k8s node注册方式ip地址**
```
#cat /usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf

[Service]
 Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf"
Environment="KUBELET_CONFIG_ARGS=--config=/var/lib/kubelet/config.yaml"
Environment="KUBELET_CGROUP_ARGS=--cgroup-driver=cgroupfs"
Environment="KUBELET_EXTRA_ARGS=--v=2 --fail-swap-on=false --pod-infra-container-image=registry.cn-hangzhou.aliyuncs.com/k8sth/pause-amd64:3.0"
#ip地址替换成nodeip地址
Environment="KUBELET_HOSTNAME_ARGS=--hostname-override=192.168.60.15"
# This is a file that "kubeadm init" and "kubeadm join" generates at runtime, populating the KUBELET_KUBEADM_ARGS variable dynamically
EnvironmentFile=-/var/lib/kubelet/kubeadm-flags.env
# This is a file that the user can use for overrides of the kubelet args as a last resort. Preferably, the user should use
# the .NodeRegistration.KubeletExtraArgs object in the configuration files instead. KUBELET_EXTRA_ARGS should be sourced from this file.
EnvironmentFile=-/etc/sysconfig/kubelet
ExecStart=
ExecStart=/usr/bin/kubelet $KUBELET_KUBECONFIG_ARGS $KUBELET_CONFIG_ARGS $KUBELET_KUBEADM_ARGS $KUBELET_EXTRA_ARGS $KUBELET_HOSTNAME_ARGS
```

**2.设置/修改k8s node角色**

#查看所有的node节点
``` 
[root@k8s-master-2 ~]# kubectl get node
NAME                     STATUS   ROLES    AGE     VERSION
192.168.60.14            Ready    master   4h48m   v1.16.8
192.168.60.15            Ready    master   10m     v1.16.8
k8s-master-1.chj.cloud   Ready    master   3d21h   v1.16.8
k8s-node-1.chj.cloud     Ready    <none>   30h     v1.16.8
 
#设置集群角色
 
# 设置 test1 为 master 角色
 
kubectl label nodes k8s-master-1.k8s.cloud node-role.kubernetes.io/master=
 
# 设置 test2 为 node 角色
 
kubectl label nodes k8s-node-1.k8s.cloud  node-role.kubernetes.io/node=
 
# 设置 master 一般情况下不接受负载
kubectl taint nodes test1 node-role.kubernetes.io/master=true:NoSchedule
 
#master运行pod
kubectl taint nodes k8s-master-1.k8s.cloud node-role.kubernetes.io/master-
 
#master不运行pod
kubectl taint nodes k8s-master-1.k8s.cloud node-role.kubernetes.io/master=:NoSchedule
```

**3.kubeadmin token过期node无法加入**
```
#使用场景
  1.通过kubeadm初始化后，都会提供node加入的token，默认token的有效期为24小时，当过期之后，该token就不可用了
 
#解决办法
[root@walker-1 kubernetes]# kubeadm token create
[kubeadm] WARNING: starting in 1.8, tokens expire after 24 hours by default (if you require a non-expiring token use --ttl 0)
zq558n.eca209zcmkoqyrva
[root@walker-1 kubernetes]# kubeadm token list
TOKEN                     TTL       EXPIRES                     USAGES                   DESCRIPTION   EXTRA GROUPS
zq558n.eca209zcmkoqyrva   23h       2017-12-26T16:36:29+08:00   authentication,
 
#获取ca证书sha256编码hash值
[root@walker-1 kubernetes]# openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'
05ad2e54678f93788b33a3591fe6069a65649d8f1d3b467388f6d0f4445c80af
 
[root@walker-4 kubernetes]# kubeadm join k8s-haproxy.k8s.cloud:6443 --token zq558n.eca209zcmkoqyrva --discovery-token-ca-cert-hash sha256:05ad2e54678f93788b33a3591fe6069a65649d8f1d3b467388f6d0f4445c80af
```

