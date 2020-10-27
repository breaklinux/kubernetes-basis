**1.部署参考地址**
- https://rancher.com/docs/rancher/v2.x/en/installation/

**2.Docker运行方式进行部署**
- Docker方式运行 注意rancher 2.4.4 以下版本api 变化无法接入 k8s 1.16.8 版本以及以上版本
```
docker run -d --name xiaolige-rancher --restart=unless-stopped -p 80:80 -p 443:443 -v /opt/rancher:/var/lib/rancher rancher/rancher:v2.4.4
```
**3.集群接入参考命令**
```
curl –insecure -sfL https://192.168.47.108/v3/import/xs54n2hrcwtdbll76b8tjppp7qprxwbjgqkf5rxg5dz2bssdsdddddd.yaml | kubectl apply -f -
clusterrole.rbac.authorization.k8s.io/proxy-clusterrole-kubeapiserver created
clusterrolebinding.rbac.authorization.k8s.io/proxy-role-binding-kubernetes-master created
namespace/cattle-system unchanged
serviceaccount/cattle unchanged
clusterrolebinding.rbac.authorization.k8s.io/cattle-admin-binding unchanged
secret/cattle-credentials-7fc402e created
clusterrole.rbac.authorization.k8s.io/cattle-admin unchanged
deployment.apps/cattle-cluster-agent configured
daemonset.apps/cattle-node-agent configured
```
