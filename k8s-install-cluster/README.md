**1.目录描述**
- deploy  #自动化部署k8s集群脚本
- deployment-problem #部署问题统计
- update-kubeadm-cert #k8s kubeadm 1年机器证书续期
- kube-flannel  #k8s flannel 网络组件安装 (适用版本:v1.22.15)
- ingress # k8s ingress 安装ingress (适用版本:v1.22.15)  

**2.单节点master部署Ingress**
- kubectl taint nodes --all node-role.kubernetes.io/master- #去除master 默认污点用于调度组件部署(适用单节点)
