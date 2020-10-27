#!/bin/env bash

#安装cfssl
install_cfssl() {
    echo -e "\033[32m 安装cfssl环境... \033[0m"
    wget https://pkg.cfssl.org/R1.2/cfssl_linux-amd64 
    wget https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
    wget https://pkg.cfssl.org/R1.2/cfssl-certinfo_linux-amd64 
    chmod +x cfssl_linux-amd64
    mv cfssl_linux-amd64 /usr/local/bin/cfssl
    chmod +x cfssljson_linux-amd64
    mv cfssljson_linux-amd64 /usr/local/bin/cfssljson
    chmod +x cfssl-certinfo_linux-amd64
    mv cfssl-certinfo_linux-amd64 /usr/local/bin/cfssl-certinfo
}

#初始化配置ca
init_ca() {
    echo -e "\033[32m 证书配置... \033[0m"
    mkdir /root/ssl
    cd /root/ssl
cat >  ca-config.json <<EOF
{
"signing": {
"default": {
    "expiry": "87600h"
  },
"profiles": {
  "kubernetes-Soulmate": {
    "usages": [
        "signing",
        "key encipherment",
        "server auth",
        "client auth"
    ],
    "expiry": "87600h"
  }
}
}
}
EOF

cat >  ca-csr.json <<EOF
{
"CN": "kubernetes-Soulmate",
"key": {
    "algo": "rsa",
    "size": 2048
    },
"names": [
    {
        "C": "CN",
        "ST": "shanghai",
        "L": "shanghai",
        "O": "k8s",
        "OU": "System"
    }
    ]
}
EOF

export PATH=/usr/local/bin:$PATH
cfssl gencert -initca ca-csr.json | cfssljson -bare ca

cat > etcd-csr.json <<EOF
{
  "CN": "etcd",
  "hosts": [
    "127.0.0.1",
    "$2",
    "$3",
    "$4"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "shanghai",
      "L": "shanghai",
      "O": "k8s",
      "OU": "System"
    }
  ]
}
EOF

cfssl gencert -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes-Soulmate etcd-csr.json | cfssljson -bare etcd
}

#分发证书
send_key() {
    echo -e "\033[32m master-1配置证书... \033[0m"
    mkdir -p /etc/etcd/ssl
    cd /root/ssl
    cp etcd.pem etcd-key.pem ca.pem /etc/etcd/ssl/
    echo -e "\033[32m 分发证书... \033[0m"
    ssh -n $3 "mkdir -p /etc/etcd/ssl && exit"
    ssh -n $4 "mkdir -p /etc/etcd/ssl && exit"
    scp -r /etc/etcd/ssl/*.pem $3:/etc/etcd/ssl/
    scp -r /etc/etcd/ssl/*.pem $4:/etc/etcd/ssl/
}

#安装etcd
install_etcd() {
    echo -e "\033[32m master-1安装etcd... \033[0m"
    yum install etcd -y
    mkdir -p /var/lib/etcd
    echo -e "\033[32m 其他master节点安装etcd... \033[0m"
    ssh -n $3 "yum install etcd -y && mkdir -p /var/lib/etcd && exit"
    ssh -n $4 "yum install etcd -y && mkdir -p /var/lib/etcd && exit"
}

#初始化etcd服务配置
init_etcd_service() {
    echo -e "\033[32m 生成相关service配置... \033[0m"
cat <<EOF >/etc/systemd/system/etcd.service
[Unit]
Description=Etcd Server
After=network.target
After=network-online.target
Wants=network-online.target
Documentation=https://github.com/coreos

[Service]
Type=notify
WorkingDirectory=/var/lib/etcd/
ExecStart=/usr/bin/etcd   --name k8s-master-1.k8s.cloud   --cert-file=/etc/etcd/ssl/etcd.pem   --key-file=/etc/etcd/ssl/etcd-key.pem   --peer-cert-file=/etc/etcd/ssl/etcd.pem   --peer-key-file=/etc/etcd/ssl/etcd-key.pem   --trusted-ca-file=/etc/etcd/ssl/ca.pem   --peer-trusted-ca-file=/etc/etcd/ssl/ca.pem   --initial-advertise-peer-urls https://$2:2380   --listen-peer-urls https://$2:2380   --listen-client-urls https://$2:2379,http://127.0.0.1:2379   --advertise-client-urls https://$2:2379   --initial-cluster-token etcd-cluster-0   --initial-cluster k8s-master-1.k8s.cloud=https://$2:2380,k8s-master-2.k8s.cloud=https://$3:2380,k8s-master-3.k8s.cloud=https://$4:2380   --initial-cluster-state new   --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
    echo -e "\033[32m 生成其他节点相关service配置... \033[0m"
cat <<EOF >/root/etcd-master-2.service
[Unit]
Description=Etcd Server
After=network.target
After=network-online.target
Wants=network-online.target
Documentation=https://github.com/coreos
 
[Service]
Type=notify
WorkingDirectory=/var/lib/etcd/
ExecStart=/usr/bin/etcd   --name k8s-master-2.k8s.cloud   --cert-file=/etc/etcd/ssl/etcd.pem   --key-file=/etc/etcd/ssl/etcd-key.pem   --peer-cert-file=/etc/etcd/ssl/etcd.pem   --peer-key-file=/etc/etcd/ssl/etcd-key.pem   --trusted-ca-file=/etc/etcd/ssl/ca.pem   --peer-trusted-ca-file=/etc/etcd/ssl/ca.pem   --initial-advertise-peer-urls https://$3:2380   --listen-peer-urls https://$3:2380   --listen-client-urls https://$3:2379,http://127.0.0.1:2379   --advertise-client-urls https://$3:2379   --initial-cluster-token etcd-cluster-0   --initial-cluster k8s-master-1.k8s.cloud=https://$2:2380,k8s-master-2.k8s.cloud=https://$3:2380,k8s-master-3.k8s.cloud=https://$4:2380   --initial-cluster-state new   --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5
LimitNOFILE=65536
 
[Install]
WantedBy=multi-user.target
EOF

cat <<EOF >/root/etcd-master-3.service
[Unit]
Description=Etcd Server
After=network.target
After=network-online.target
Wants=network-online.target
Documentation=https://github.com/coreos

[Service]
Type=notify
WorkingDirectory=/var/lib/etcd/
ExecStart=/usr/bin/etcd   --name k8s-master-3.k8s.cloud   --cert-file=/etc/etcd/ssl/etcd.pem   --key-file=/etc/etcd/ssl/etcd-key.pem   --peer-cert-file=/etc/etcd/ssl/etcd.pem   --peer-key-file=/etc/etcd/ssl/etcd-key.pem   --trusted-ca-file=/etc/etcd/ssl/ca.pem   --peer-trusted-ca-file=/etc/etcd/ssl/ca.pem   --initial-advertise-peer-urls https://$4:2380   --listen-peer-urls https://$4:2380   --listen-client-urls https://$4:2379,http://127.0.0.1:2379   --advertise-client-urls https://$4:2379   --initial-cluster-token etcd-cluster-0   --initial-cluster k8s-master-1.k8s.cloud=https://$2:2380,k8s-master-2.k8s.cloud=https://$3:2380,k8s-master-3.k8s.cloud=https://$4:2380   --initial-cluster-state new   --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
    
    echo -e "\033[32m 分发etcd.service... \033[0m"
    scp /root/etcd-master-2.service $3:/etc/systemd/system/etcd.service
    scp /root/etcd-master-3.service $4:/etc/systemd/system/etcd.service
}

#启动etcd
start_etcd() {
    echo -e "\033[32m 添加etcd自启动... \033[0m"
    mv /etc/systemd/system/etcd.service /usr/lib/systemd/system/
    ssh -n $3 "mv /etc/systemd/system/etcd.service /usr/lib/systemd/system/"
    ssh -n $4 "mv /etc/systemd/system/etcd.service /usr/lib/systemd/system/"

    systemctl daemon-reload
    systemctl enable etcd
    ssh -n $3 "systemctl daemon-reload && systemctl enable etcd && exit"
    ssh -n $4 "systemctl daemon-reload && systemctl enable etcd && exit"

    echo -e "\033[32m 启动etcd... \033[0m"
    systemctl start etcd
    systemctl status etcd
    ssh -n $3 "systemctl start etcd && systemctl status etcd && exit"
    ssh -n $4 "systemctl start etcd && systemctl status etcd && exit"
}

#检查etcd节点
chekc_etcd() {
    echo -e "\033[32m 检测etcd节点... \033[0m"
    export ETCDCTL_API=3;etcdctl --endpoints=https://$2:2379,https://$3:2379,https://$4:2379 --cacert=/etc/etcd/ssl/ca.pem --cert=/etc/etcd/ssl/etcd.pem --key=/etc/etcd/ssl/etcd-key.pem endpoint health
}

#安装docker
install_docker() {
    echo -e "\033[32m 设置docker源... \033[0m"
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo

    yum install -y https://mirrors.aliyun.com/docker-ce/linux/centos/7/x86_64/stable/Packages/docker-ce-19.03.8-3.el7.x86_64.rpm
    yum install -y docker-ce-cli.x86_64
    yum install -y docker-ce.x86_64

    ssh -n $3 "yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo && yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo && yum install -y https://mirrors.aliyun.com/docker-ce/linux/centos/7/x86_64/stable/Packages/docker-ce-19.03.8-3.el7.x86_64.rpm && yum install -y docker-ce-cli.x86_64 docker-ce.x86_64"
    ssh -n $4 "yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo && yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo && yum install -y https://mirrors.aliyun.com/docker-ce/linux/centos/7/x86_64/stable/Packages/docker-ce-19.03.8-3.el7.x86_64.rpm && yum install -y docker-ce-cli.x86_64 docker-ce.x86_64"
    ssh -n $5 "yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo && yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo && yum install -y https://mirrors.aliyun.com/docker-ce/linux/centos/7/x86_64/stable/Packages/docker-ce-19.03.8-3.el7.x86_64.rpm && yum install -y docker-ce-cli.x86_64 docker-ce.x86_64"

    echo -e "\033[32m 变更配置文件... \033[0m"

   cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ]
}
EOF



    cat >/usr/lib/systemd/system/docker.service << EOF
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
BindsTo=containerd.service
After=network-online.target firewalld.service containerd.service
Wants=network-online.target
Requires=docker.socket

[Service]
Type=notify
# ExecStart=/usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock
ExecStart=/usr/bin/dockerd   -H tcp://$2:2375 -H unix:///var/run/docker.sock  --registry-mirror=https://ms3cfraz.mirror.aliyuncs.com --bip=10.31.0.1/16  --graph /chj/nodedata/docker/
ExecReload=/bin/kill -s HUP \$MAINPID
TimeoutSec=0
RestartSec=2
Restart=always
StartLimitBurst=3
StartLimitInterval=60s
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
Delegate=yes
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

    cat >/root/docker3.service << EOF
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
BindsTo=containerd.service
After=network-online.target firewalld.service containerd.service
Wants=network-online.target
Requires=docker.socket

[Service]
Type=notify
# ExecStart=/usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock
ExecStart=/usr/bin/dockerd   -H tcp://$3:2375 -H unix:///var/run/docker.sock  --registry-mirror=https://ms3cfraz.mirror.aliyuncs.com --bip=10.31.0.1/24  --graph /chj/nodedata/docker/
ExecReload=/bin/kill -s HUP \$MAINPID
TimeoutSec=0
RestartSec=2
Restart=always
StartLimitBurst=3
StartLimitInterval=60s
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
Delegate=yes
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

    cat >/root/docker4.service << EOF
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
BindsTo=containerd.service
After=network-online.target firewalld.service containerd.service
Wants=network-online.target
Requires=docker.socket

[Service]
Type=notify
# ExecStart=/usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock
ExecStart=/usr/bin/dockerd   -H tcp://$4:2375 -H unix:///var/run/docker.sock  --registry-mirror=https://ms3cfraz.mirror.aliyuncs.com --bip=10.31.0.0/24  --graph /chj/nodedata/docker/
ExecReload=/bin/kill -s HUP \$MAINPID
TimeoutSec=0
RestartSec=2
Restart=always
StartLimitBurst=3
StartLimitInterval=60s
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
Delegate=yes
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

    cat >/root/docker5.service << EOF
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
BindsTo=containerd.service
After=network-online.target firewalld.service containerd.service
Wants=network-online.target
Requires=docker.socket

[Service]
Type=notify
# ExecStart=/usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock
ExecStart=/usr/bin/dockerd   -H tcp://$5:2375 -H unix:///var/run/docker.sock  --registry-mirror=https://ms3cfraz.mirror.aliyuncs.com --bip=10.31.0.1/16  --graph /chj/nodedata/docker/
ExecReload=/bin/kill -s HUP \$MAINPID
TimeoutSec=0
RestartSec=2
Restart=always
StartLimitBurst=3
StartLimitInterval=60s
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
Delegate=yes
KillMode=process

[Install]
WantedBy=multi-user.target
EOF
    scp /root/docker3.service $3:/usr/lib/systemd/system/docker.service
    scp /root/docker4.service $4:/usr/lib/systemd/system/docker.service
    scp /root/docker5.service $5:/usr/lib/systemd/system/docker.service

    echo -e "\033[32m 启动docker... \033[0m"

    systemctl daemon-reload
    systemctl restart docker
    systemctl enable docker
    systemctl status docker

    ssh -n $3 "systemctl daemon-reload && systemctl restart docker && systemctl enable docker && systemctl status docker"
    ssh -n $4 "systemctl daemon-reload && systemctl restart docker && systemctl enable docker && systemctl status docker"
    ssh -n $5 "systemctl daemon-reload && systemctl restart docker && systemctl enable docker && systemctl status docker"

}

#安装kubelet kubectl kubeadm
install_init_kubeall() {

    echo -e "\033[32m 安装 kubelet kubectl kubeadm... \033[0m"
    yum -y install kubelet-1.16.8
    yum -y install kubectl-1.16.8
    yum -y install kubeadm-1.16.8
    systemctl enable kubelet

    ssh -n $3 "yum -y install kubelet-1.16.8 kubectl-1.16.8 kubeadm-1.16.8 && systemctl enable kubelet"
    ssh -n $4 "yum -y install kubelet-1.16.8 kubectl-1.16.8 kubeadm-1.16.8 && systemctl enable kubelet"
    ssh -n $5 "yum -y install kubelet-1.16.8 kubectl-1.16.8 kubeadm-1.16.8 && systemctl enable kubelet"

    echo -e "\033[32m 配置 kubelet... \033[0m"
    
    cat > /usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf <<EOF
# Note: This dropin only works with kubeadm and kubelet v1.11+
[Service]
Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf"
Environment="KUBELET_CONFIG_ARGS=--config=/var/lib/kubelet/config.yaml"
Environment="KUBELET_CGROUP_ARGS=--cgroup-driver=cgroupfs"
Environment="KUBELET_EXTRA_ARGS=--v=2 --fail-swap-on=false --pod-infra-container-image=registry.cn-hangzhou.aliyuncs.com/k8sth/pause-amd64:3.0"
# This is a file that "kubeadm init" and "kubeadm join" generates at runtime, populating the KUBELET_KUBEADM_ARGS variable dynamically
EnvironmentFile=-/var/lib/kubelet/kubeadm-flags.env
# This is a file that the user can use for overrides of the kubelet args as a last resort. Preferably, the user should use
# the .NodeRegistration.KubeletExtraArgs object in the configuration files instead. KUBELET_EXTRA_ARGS should be sourced from this file.
EnvironmentFile=-/etc/sysconfig/kubelet
ExecStart=
ExecStart=/usr/bin/kubelet \$KUBELET_KUBECONFIG_ARGS \$KUBELET_CONFIG_ARGS \$KUBELET_KUBEADM_ARGS \$KUBELET_EXTRA_ARGS
EOF

    scp /usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf $3:/usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf
    scp /usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf $4:/usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf
    scp /usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf $5:/usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf

    echo -e "\033[32m reload kubelet... \033[0m"
    systemctl daemon-reload
    systemctl enable kubelet
    ssh -n $3 "systemctl daemon-reload && systemctl enable kubelet"
    ssh -n $4 "systemctl daemon-reload && systemctl enable kubelet"
    ssh -n $5 "systemctl daemon-reload && systemctl enable kubelet"
}

#安装相关命令补全
install_other() {
    echo -e "\033[32m 安装命令补全... \033[0m"
    yum install -y bash-completion
    source /usr/share/bash-completion/bash_completion
    kubectl completion bash > source
    echo "source <(kubectl completion bash)" >> ~/.bashrc

    ssh -n $3 "yum install -y bash-completion && source /usr/share/bash-completion/bash_completion && kubectl completion bash > source && echo \"source <(kubectl completion bash)\" >> ~/.bashrc"
    ssh -n $4 "yum install -y bash-completion && source /usr/share/bash-completion/bash_completion && kubectl completion bash > source && echo \"source <(kubectl completion bash)\" >> ~/.bashrc"
    ssh -n $5 "yum install -y bash-completion && source /usr/share/bash-completion/bash_completion && kubectl completion bash > source && echo \"source <(kubectl completion bash)\" >> ~/.bashrc"
}

#init master-1
init_master_join_node() {
    echo -e "\033[32m 初始化master-1... \033[0m"
    cat > new.yaml <<EOF
apiVersion: kubeadm.k8s.io/v1beta2
bootstrapTokens:
- groups:
  - system:bootstrappers:kubeadm:default-node-token
  token: m4mz9x.zdc6kux5q2cjq0dy
  ttl: 24h0m0s
  usages:
  - signing
  - authentication
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: $1
  bindPort: 6443
nodeRegistration:
  criSocket: /var/run/dockershim.sock
  name: k8s-master-1.k8s.cloud
  taints:
  - effect: NoSchedule
    key: node-role.kubernetes.io/master
---
apiServer:
  certSANs:
  - k8s-haproxy.k8s.cloud
  - $2
  - $3
  - $4
  - k8s-master-1.k8s.cloud
  - k8s-master-2.k8s.cloud
  - k8s-master-3.k8s.cloud
  timeoutForControlPlane: 4m0s
apiVersion: kubeadm.k8s.io/v1beta2
certificatesDir: /etc/kubernetes/pki
clusterName: kubernetes
controlPlaneEndpoint: k8s-haproxy.k8s.cloud:6443
controllerManager: {}
dns:
  type: CoreDNS
etcd:
  external:
    caFile: /etc/etcd/ssl/ca.pem
    certFile: /etc/etcd/ssl/etcd.pem
    endpoints:
    - https://$2:2379
    - https://$3:2379
    - https://$3:2379
    keyFile: /etc/etcd/ssl/etcd-key.pem
imageRepository: k8s.gcr.io
kind: ClusterConfiguration
kubernetesVersion: v1.16.8
networking:
  dnsDomain: cluster.local
  serviceSubnet: 10.31.48.0/22
  podSubnet: 10.31.32.0/19
scheduler: {}

EOF

    #kubeadm config migrate --old-config config.yaml --new-config new.yaml
    kubeadm init --config new.yaml > kubeadm.log
    echo -e "\033[32m 节点加入命令如下... \033[0m"
    grep "kubeadm join" -A 2 kubeadm.log

    echo -e "\033[32m master节点加入集群... \033[0m"
    #分发相关密码文件
    mkdir -p $HOME/.kube
    cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    chown $(id -u):$(id -g) $HOME/.kube/config
    scp -r /etc/kubernetes/pki  $3:/etc/kubernetes/
    scp -r /etc/kubernetes/pki  $4:/etc/kubernetes/

    #网络插件
    #Cilium 网络插件
    kubectl create -f https://raw.githubusercontent.com/cilium/cilium/1.7.3/install/kubernetes/quick-install.yaml
    
    kube_master_command = grep "kubeadm join" -A 2 kubeadm.log|grep -v "Then you can"|head -2
    ssh -n $3 "$kube_master_command"
    ssh -n $4 "$kube_master_command"

    echo -e "\033[32m node节点加入集群... \033[0m"
    kube_node_command = grep "kubeadm join" -A 2 kubeadm.log|grep -v "Then you can"|tail -2
    ssh -n $5 "$kube_node_command"

    echo -e "\033[32m 查看集群nodes状态... \033[0m"
    kubectl get nodes

    echo -e "\033[32m 查看集群pods状态... \033[0m"
    kubectl get pods -n kube-system
}


main() {
    install_cfssl
    init_ca $*
    send_key $*
    install_etcd $*
    init_etcd_service $*
    start_etcd $*
    chekc_etcd $*
    install_docker $*
    install_init_kubeall $*
    install_other $*
    init_master_join_node $*
}


case $1 in 
    "all")
        main $*
        ;;
    "install_etcd")
        install_cfssl
        init_ca $*
        send_key $*
        install_etcd $*
        install_etcd $*
        init_etcd_service $*
        start_etcd $*
        chekc_etcd $*
        ;;
    "install_docker")
        install_docker $*
        ;;
    "install_kube")
        install_init_kubeall $*
        install_other $*
        ;;
    "init_Kubernetes")
    init_master_join_node $*
     ;;
    *)
        echo -e "\033[32m 参数如下: \033[0m"
        echo -e "\033[32m install_etcd \033[0m 安装etcd 后面跟节点ip"
        echo -e "\033[32m install_docker \033[0m 安装docker 后面跟ip"
        echo -e "\033[32m install_kube \033[0m 安装kubenetes相关 后面跟ip"
        echo -e "\033[32m init_Kubernetes \033[0m kubenetes_init 后面跟ip"
        echo -e "\033[32m all \033[0m 一键kubernetes安装 后面跟 matser_ip1 matser_ip2 matser_ip3 node_ip"
        ;;
esac
