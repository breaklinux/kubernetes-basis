#/bin/bash
#desc 修改kube-proxy 工作模式为ipvs模式
init(){
yum -y install ipset ipvsadm 
}

configIpvsModel(){
mkdir -p /root/ipvs/
#注意:内核版本在4.19.1--5.x版本内核内核中 nf_conntrack_ipv4 已经修改为nf_conntrack模块
cat > /root/ipvs/ipvs.sh <<EOF
modprobe  ip_vs
modprobe  ip_vs_rr
modprobe  ip_vs_wrr
modprobe  ip_vs_sh
modprobe  nf_conntrack 
#modprobe  nf_conntrack_ipv4
EOF
/bin/bash  /root/ipvs/ipvs.sh 
echo "/bin/bash /root/ipvs/ipvs.sh" >>/etc/rc.local

}

viewIpvs(){
lsmod |grep ip_vs
}

rollout_restart_kube_proxy(){

kubectl rollout restart daemonset kube-proxy -n kube-system

}


config_ipvs_model(){
kubectl get   configmap -n kube-system  kube-proxy -o yaml >> config_map_ipvs_kube_proxy.yaml
cp config_map_ipvs_kube_proxy.yaml config_map_default_kube_proxy.yaml.bak
sed -i 's/mode: ""/mode: "ipvs"/g' config_map_ipvs_kube_proxy.yaml
kubectl delete  configmaps kube-proxy -n kube-system 
kubectl apply -f config_map_ipvs_kube_proxy.yaml
rollout_restart_kube_proxy
} 


main() {
   init
   load_ipvs_module $*
   viewIpvs $*
   config_ipvs_model $*
   rollout_restart_kube_proxy $*
}




case $1 in 
    "all")
        main $*
        ;;
    "load_ipvs_module")
        init
        configIpvsModel $*
        ;;
    "view_ipvs")
        viewIpvs $*
        ;;
    "config_ipvs_Model")
        config_ipvs_model $* 
        ;;
    "graceful_restart")
     rollout_restart_kube_proxy $*
     ;;
    *)
        echo -e "\033[32m 参数如下: \033[0m"
        echo -e "\033[32m load_ipvs_module \033[0m 系统内核加载支持ipvs模块"
        echo -e "\033[32m view_ipvs \033[0m 验证系统节点开启ipvs模块"
        echo -e "\033[32m config_ipvs_Model \033[0m 设置kube_proxy_ipvs模式"
        echo -e "\033[32m graceful_restart \033[0m 滚动重启kube-proxy"
        echo -e "\033[32m all \033[0m 配置ipvs所有功能"
        ;;
esac
