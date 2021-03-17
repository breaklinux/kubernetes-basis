一、前言
dm初始化k8s集群，签发的CA证书有效期默认是10年，签发的apiserver证书有效期默认是1年，到期之后请求apiserver会报错，使用openssl命令查询相关证书是否到期。 以下延长证书过期的方法适合kubernetes1.14、1.15、1.16、1.17、1.18版本

二、查看证书有效时间
openssl x509 -in /etc/kubernetes/pki/ca.crt -noout -text  |grep Not

显示如下，通过下面可看到ca证书有效期是10年，从2020到2030年：
Not Before: Apr 22 04:09:07 2020 GMT
Not After : Apr 20 04:09:07 2030 GMT

openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -text  |grep Not

显示如下，通过下面可看到apiserver证书有效期是1年，从2020到2021年：
Not Before: Apr 22 04:09:07 2020 GMT
Not After : Apr 22 04:09:07 2021 GMT
三、延长证书过期时间
1.把update-kubeadm-cert.sh文件上传到master1、master2、master3节点
update-kubeadm-cert.sh文件所在的github地址如下：
https://github.com/luckylucky421/kubernetes1.17.3
把update-kubeadm-cert.sh文件clone和下载下来，拷贝到master1，master2，master3节点上

2.在每个节点都执行如下命令
1）给update-kubeadm-cert.sh证书授权可执行权限
chmod +x update-kubeadm-cert.sh

2）执行下面命令，修改证书过期时间，把时间延长到10年
./update-kubeadm-cert.sh all

3）在master1节点查询Pod是否正常,能查询出数据说明证书签发完成
kubectl  get pods -n kube-system

显示如下，能够看到pod信息，说明证书签发正常：
......
[root@k8s-node02 pki]# kubectl get pod -n kube-system -o wide
NAME                                                 READY   STATUS    RESTARTS   AGE     IP              NODE                         NOMINATED NODE   READINESS GATES
cilium-4pjl8                                         1/1     Running   2          42d     192.168.58.13   k8s-node02.xiaolige.site     <none>           <none>
cilium-dx72r                                         1/1     Running   3          42d     192.168.58.10   k8s-node03.xiaolige.site     <none>           <none>
cilium-operator-59b8b544d4-w6l2d                     1/1     Running   9          4d22h   192.168.58.13   k8s-node02.xiaolige.site     <none>           <none>
cilium-s77qk                                         1/1     Running   1          42d     192.168.58.5    k8s-master01.xiaolige.site   <none>           <none>
coredns-5644d7b6d9-jbxz6                             1/1     Running   1          50d     10.5.163.197    k8s-master01.xiaolige.site   <none>           <none>
coredns-5644d7b6d9-n9kx5                             1/1     Running   1          50d     10.5.190.121    k8s-master01.xiaolige.site   <none>           <none>
kube-apiserver-k8s-master01.xiaolige.site            1/1     Running   2          50d     192.168.58.5    k8s-master01.xiaolige.site   <none>           <none>
kube-controller-manager-k8s-master01.xiaolige.site   1/1     Running   167        50d     192.168.58.5    k8s-master01.xiaolige.site   <none>           <none>
kube-proxy-6ldwd                                     1/1     Running   0          30m     192.168.58.5    k8s-master01.xiaolige.site   <none>           <none>
kube-proxy-lf7g4                                     1/1     Running   0          32m     192.168.58.13   k8s-node02.xiaolige.site     <none>           <none>
kube-proxy-pd5n9                                     1/1     Running   0          30m     192.168.58.10   k8s-node03.xiaolige.site     <none>           <none>
kube-scheduler-k8s-master01.xiaolige.site            1/1     Running   164        50d     192.168.58.5    k8s-master01.xiaolige.site   <none>           <none>
......
四、验证证书有效时间是否延长到10年
openssl x509 -in /etc/kubernetes/pki/ca.crt -noout -text  |grep Not
显示如下，通过下面可看到ca证书有效期是10年，从2020到2030年：
Not Before: Apr 22 04:09:07 2020 GMT
Not After : Apr 20 04:09:07 2030 GMT
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -text  |grep Not
显示如下，通过下面可看到apiserver证书有效期是10年，从2020到2030年：
Not Before: Apr 22 11:15:53 2020 GMT
Not After : Apr 20 11:15:53 2030 GMT
openssl x509 -in /etc/kubernetes/pki/apiserver-etcd-client.crt  -noout -text  |grep Not
显示如下，通过下面可看到etcd证书有效期是10年，从2020到2030年：
Not Before: Apr 22 11:32:24 2020 GMT
Not After : Apr 20 11:32:24 2030 GMT
openssl x509 -in /etc/kubernetes/pki/front-proxy-ca.crt  -noout -text  |grep Not
显示如下，通过下面可看到fron-proxy证书有效期是10年，从2020到2030年：
Not Before: Apr 22 04:09:08 2020 GMT
Not After : Apr 20 04:09:08 2030 GMT
参考资料：

https://mp.weixin.qq.com/s/N7WRT0OkyJHec35BH_X1Hg kubeadm初始化k8s集群延长证书过期
