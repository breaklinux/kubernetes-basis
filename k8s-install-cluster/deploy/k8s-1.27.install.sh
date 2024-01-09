#!/bin/env bash
#
#安装cfssl
install_cfssl() {
    sh_path=$(cd $sh_path;pwd)
    pkg_count=$(ls -rt  $sh_path  |grep -E "cfssl-certinfo_linux-amd64|cfssljson_linux-amd64|cfssl_linux-amd64" |wc -l)
    if [ $pkg_count != "3" ]
    then
      echo -e "\033[32m 本地未找到cfssl包从网络安装cfssl环境... \033[0m"
      wget https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
      wget https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
      wget https://pkg.cfssl.org/R1.2/cfssl-certinfo_linux-amd64
    fi
      echo -e "\033[32m 本地脚本目录找到cfssl包-本地安装cfssl环境... \033[0m"
      chmod +x cfssl_linux-amd64
      cp -rpf  cfssl_linux-amd64 /usr/local/bin/cfssl
      chmod +x cfssljson_linux-amd64
      cp -rpf cfssljson_linux-amd64 /usr/local/bin/cfssljson
      chmod +x cfssl-certinfo_linux-amd64
      cp -rpf cfssl-certinfo_linux-amd64 /usr/local/bin/cfssl-certinfo
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
ExecStart=/usr/bin/etcd   --name k8s-etcd-1.k8s.com  --peer-client-cert-auth --client-cert-auth --cert-file=/etc/etcd/ssl/etcd.pem   --key-file=/etc/etcd/ssl/etcd-key.pem   --peer-cert-file=/etc/etcd/ssl/etcd.pem   --peer-key-file=/etc/etcd/ssl/etcd-key.pem   --trusted-ca-file=/etc/etcd/ssl/ca.pem   --peer-trusted-ca-file=/etc/etcd/ssl/ca.pem   --initial-advertise-peer-urls https://$2:2380   --listen-peer-urls https://$2:2380   --listen-client-urls https://$2:2379,http://127.0.0.1:2379   --advertise-client-urls https://$2:2379   --initial-cluster-token etcd-cluster-0   --initial-cluster k8s-etcd-1.k8s.com=https://$2:2380,k8s-etcd-2.k8s.com=https://$3:2380,k8s-etcd-3.k8s.com=https://$4:2380   --initial-cluster-state new   --data-dir=/var/lib/etcd
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
ExecStart=/usr/bin/etcd   --name k8s-etcd-2.k8s.com   --peer-client-cert-auth --client-cert-auth --cert-file=/etc/etcd/ssl/etcd.pem   --key-file=/etc/etcd/ssl/etcd-key.pem   --peer-cert-file=/etc/etcd/ssl/etcd.pem   --peer-key-file=/etc/etcd/ssl/etcd-key.pem   --trusted-ca-file=/etc/etcd/ssl/ca.pem   --peer-trusted-ca-file=/etc/etcd/ssl/ca.pem   --initial-advertise-peer-urls https://$3:2380   --listen-peer-urls https://$3:2380   --listen-client-urls https://$3:2379,http://127.0.0.1:2379   --advertise-client-urls https://$3:2379   --initial-cluster-token etcd-cluster-0   --initial-cluster k8s-etcd-1.k8s.com=https://$2:2380,k8s-etcd-2.k8s.com=https://$3:2380,k8s-etcd-3.k8s.com=https://$4:2380   --initial-cluster-state new   --data-dir=/var/lib/etcd
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
ExecStart=/usr/bin/etcd   --name k8s-etcd-3.k8s.com  --peer-client-cert-auth --client-cert-auth  --cert-file=/etc/etcd/ssl/etcd.pem   --key-file=/etc/etcd/ssl/etcd-key.pem   --peer-cert-file=/etc/etcd/ssl/etcd.pem   --peer-key-file=/etc/etcd/ssl/etcd-key.pem   --trusted-ca-file=/etc/etcd/ssl/ca.pem   --peer-trusted-ca-file=/etc/etcd/ssl/ca.pem   --initial-advertise-peer-urls https://$4:2380   --listen-peer-urls https://$4:2380   --listen-client-urls https://$4:2379,http://127.0.0.1:2379   --advertise-client-urls https://$4:2379   --initial-cluster-token etcd-cluster-0   --initial-cluster k8s-etcd-1.k8s.com=https://$2:2380,k8s-etcd-2.k8s.com=https://$3:2380,k8s-etcd-3.k8s.com=https://$4:2380   --initial-cluster-state new   --data-dir=/var/lib/etcd
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
    echo -e echo -e "\033[32m 检测检查命令... export ETCDCTL_API=3;etcdctl --endpoints=https://$2:2379,https://$3:2379,https://$4:2379 --cacert=/etc/etcd/ssl/ca.pem --cert=/etc/etcd/ssl/etcd.pem --key=/etc/etcd/ssl/etcd-key.pem endpoint health \033[0m"
}

#安装containerd
install_containerd() {
    echo -e "\033[32m 设置docker containerd源... \033[0m"
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    yum device-mapper-persistent-data lvm2 coreutils
    yum install -y docker-ce-20.10.* docker-ce-cli-20.10.* containerd
    ssh -n $3 "yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo && yum device-mapper-persistent-data lvm2 coreutils  -y && yum install docker-ce-20.10.* docker-ce-cli-20.10.* containerd.io -y"
    ssh -n $4 "yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo && yum device-mapper-persistent-data lvm2 coreutils  -y && yum install docker-ce-20.10.* docker-ce-cli-20.10.*  containerd -y"
    ssh -n $5 "yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo && yum device-mapper-persistent-data lvm2 coreutils  -y && yum docker-ce-20.10.* docker-ce-cli-20.10.* containerd -y"
    cat << EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
   modprobe -- overlay
   modprobe -- br_netfilter
   echo -e "\033[32m 变更配置文件-设置cgroups... \033[0m"

mkdir -p /etc/containerd
# 生成默认配置文件
containerd config default | tee /etc/containerd/config.toml

# 修改 SystemdCgroup 配置
sed -i "s#SystemdCgroup\ \=\ false#SystemdCgroup\ \=\ true#g" /etc/containerd/config.toml
cat /etc/containerd/config.toml | grep SystemdCgroup

# 修改 pause 镜像
sed -i "s#registry.k8s.io#registry.cn-hangzhou.aliyuncs.com/google_containers#g" /etc/containerd/config.toml
cat /etc/containerd/config.toml | grep sandbox_image

#containerd 本节点 服务启动
    scp -rpf /etc/containerd/config.toml $4:/etc/containerd/config.toml
    scp -rpf /etc/containerd/config.toml $5:/etc/containerd/config.toml

    echo -e "\033[32m containerd 节点-启动... \033[0m"
    ssh -n $3 "systemctl daemon-reload && systemctl restart containerd && systemctl enable --now containerd && systemctl status containerd"
    ssh -n $4 "systemctl daemon-reload && systemctl restart containerd && systemctl enable --now containerd && systemctl status containerd"
    ssh -n $5 "systemctl daemon-reload && systemctl restart containerd && systemctl enable --now containerd && systemctl status containerd"
}

# 安装配置 crictl 客户端
install_crictl(){
    sh_path=$(cd $sh_path;pwd)
    pkg_count=$(ls -rt  $sh_path  |grep -E "crictl-*-linux-amd64.tar.gz")
    if [ $pkg_count != "1" ]
    then
      echo -e "\033[32m 本地未找到crictl 客户端包 从网络下载环境... \033[0m"
      wget https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.27.0/crictl-v1.27.0-linux-amd64.tar.gz
    fi
      echo -e "\033[32m 本地未找到crictl 客户端包 本地安装环境... \033[0m"
      tar xf crictl-v*-linux-amd64.tar.gz -C /usr/bin/
      chmod +x /usr/bin/crictl
      cat > /etc/crictl.yaml <<EOF
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF
     crictl info
     echo -e "\033[32m crictl配置文件 crictl 客户端包 远程其他环境... \033[0m"
     scp -rpf /etc/crictl.yaml $4:/etc/crictl.yaml
     scp -rpf /etc/crictl.yaml $5:/etc/crictl.yaml

     scp -rpf /usr/bin/crictl $4:/usr/bin/crictl
     scp -rpf /usr/bin/crictl $5:/usr/bin/crictl
}

#安装kubelet kubectl kubeadm
install_init_kubeall() {

    echo -e "\033[32m 安装 kubelet kubectl kubeadm... \033[0m"
    yum -y install kubelet-1.27.0
    yum -y install kubectl-1.27.0
    yum -y install kubeadm-1.27.0
    systemctl enable kubelet

    ssh -n $3 "yum -y install kubelet-1.27.0 kubectl-1.27.0 kubeadm-1.27.0 && systemctl enable kubelet"
    ssh -n $4 "yum -y install kubelet-1.27.0 kubectl-1.27.0 kubeadm-1.27.0 && systemctl enable kubelet"
    ssh -n $5 "yum -y install kubelet-1.27.0 kubectl-1.27.0 kubeadm-1.27.0&& systemctl enable kubelet"

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
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
bootstrapTokens:
  - token: "9a08jv.c0izixklcxtmnze7"
    description: "kubeadm bootstrap token"
    ttl: "24h"
  - token: "783bde.3f89s0fje9f38fhf"
    description: "another bootstrap token"
    usages:
      - authentication
      - signing
    groups:
      - system:bootstrappers:kubeadm:default-node-token
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
etcd:
  external:
    endpoints:
      - https://192.168.0.201:2379
      - https://192.168.0.201:2379
      - https://192.168.0.201:2379
    caFile: "/etcd/kubernetes/pki/etcd/etcd-ca.crt"
    certFile: "/etcd/kubernetes/pki/etcd/etcd.crt"
    keyFile: "/etcd/kubernetes/pki/etcd/etcd.key"
networking:
  serviceSubnet: "10.31.48.0/18"
  podSubnet: "10.31.0.0/17"
  dnsDomain: "cluster.local"
kubernetesVersion: "v1.27.0"
controlPlaneEndpoint: "k8s-haproxy.k8s.cloud:6443"
apiServer:
  certSANs:
    - k8s-haproxy.k8s.cloud
    - k8s-master-1.k8s.cloud
    - k8s-master-2.k8s.cloud
    - k8s-master-3.k8s.cloud
  timeoutForControlPlane: 4m0s
certificatesDir: "/etc/kubernetes/pki"
imageRepository: "registry.cn-hangzhou.aliyuncs.com/google_containers"
---
apiVersion: kubeproxy.config.k8s.io/v1beta3
kind: KubeProxyConfiguration
mode: ipvs
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


install_helm3.13.3(){
    if ! command -v helm &> /dev/null
    then
         sh_path=$(cd $sh_path;pwd)
         pkg_count=$(ls -rt  $sh_path |grep -E "helm-v3.13.3-linux-amd64.tar.gz"|wc -l)
         if [ $pkg_count != "1" ]
         then
            echo -e "\033[32m 本地未找到Helm包从网络Helm安装环境... \033[0m"
            wget https://get.helm.sh/helm-v3.13.3-linux-amd64.tar.gz
         fi
         tar xf helm-v3.13.3-linux-amd64.tar.gz
         cd linux-amd64/ && chmod +x helm && cp -rpf helm /usr/bin/helm
    else
        echo -e "\033[32m Helm包本地已经存在安装失败... \033[0m"
    fi
}

install_cni_cilium(){
if ! command -v helm &> /dev/null
then
   install_helm3.13.3
fi
helm repo add cilium https://helm.cilium.io/
helm install cilium cilium/cilium --namespace=kube-system
}


kubeadm_config_init_defaults(){
#打印默认的节点添加配置，
echo -e "\033[32m kubeadm 初始化配置文件生成-可提供参考特殊参数.可选配置.. \033[0m"
kubeadm config print init-defaults > init_kubeadm_config.yaml
}

kubeadm_config_init_defaults(){
#打印默认的节点添加配置，
echo -e "\033[32m kubeadm 初始化配置文件生成-可提供参考特殊参数... \033[0m"
kubeadm config print init-defaults > init_kubeadm_config.yaml
}

kubeadm_config_image(){
kubeadm_config_path = $3
if [ ! -z $kubeadm_config_path ]
then
  echo -e "\033[32m kubeadm images 检查镜像和拉取 kubeadm 使用的镜像.. \033[0m"
  kubeadm config images list --config $kubeadm_config_path
  kubeadm config images pull --config $kubeadm_config_path
else
  echo -e "\033[31m kubeadm 输出了无效配置文件路径-或者kubeadm config配置路径不存在... \033[0m"
fi
}
main() {
    install_cfssl
    init_ca $*
    send_key $*
    install_etcd $*
    init_etcd_service $*
    start_etcd $*
    chekc_etcd $*
    install_containerd $*
    install_crictl $*
    install_init_kubeall $*
    install_other $*
    init_master_join_node $*
    install_Helm
    install_cni_cilium
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
    "check_etcd")
        chekc_etcd $*
        ;;
    "install_containerd")
        install_containerd $*
        install_crictl $*
        ;;
    "install_kube")
        install_init_kubeall $*
        install_other $*
        ;;
    "init_Kubernetes")
    init_master_join_node $*
     ;;
    "install_Helm")
      install_helm3.13.3
    ;;
    "install_cni_cilium")
      install_cni_cilium
      ;;
     "kubeadm_config_init_defaults")
      kubeadm_config_init_defaults
      ;;
      "kubeadm_config_image")
        kubeadm_config_image
      ;;
    *)
        echo -e "\033[32m 参数如下: \033[0m"
        echo -e "\033[32m install_etcd \033[0m 安装etcd 后面跟节点ip"
        echo -e "\033[32m check_etcd \033[0m 检查3个 etcd状态 后面跟节点ip"
        echo -e "\033[32m install_containerd \033[0m 安装containerd 后面跟ip"
        echo -e "\033[32m install_kube \033[0m 安装kubenetes相关 后面跟ip"
        echo -e "\033[32m init_Kubernetes \033[0m kubenetes_init 后面跟ip"
        echo -e "\033[32m install_Helm \033[0m install_Helm 安装在master01节点-无需参数"
        echo -e "\033[32m kubeadm_config_init_defaults \033[0m kubeadm_config_init_defaults-自动生成默认配置文件-自定义可参考修改"
        echo -e "\033[32m kubeadm_config_image \033[0m kubeadm_config_image kubeadm镜像查询和拉取-后面跟-kubeadm配置文件路径"
        echo -e "\033[32m install_cni_cilium \033[0m install_cni_cilium 安装集群部成功后执行-安装cilium网络组件"
        echo -e "\033[32m all \033[0m 一键kubernetes安装 后面跟 matser_ip1 matser_ip2 matser_ip3 "
        ;;
esac
