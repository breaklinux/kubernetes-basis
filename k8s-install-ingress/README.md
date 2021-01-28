**1.部署k8s-nginx-ingress服务**
```
   #环境依赖:
   - k8s 1.14 以上版本
   - k8s 核心组件及网络插件正常部署
```
**2.部署说明**
```
kubectl apply -f ./deploy.yaml
```
**3.查看部署结果**
```
kubectl get pod -n ingress-nginx
NAME                                       READY   STATUS     RESTARTS   AGE
ingress-nginx-admission-create-57qv8       0/1     Completed   0          1s
ingress-nginx-admission-patch-qjlm6        0/1     Completed   0          1s
ingress-nginx-controller-f8d756996-77jv4   1/1     Running     0          1s
ingress-nginx-controller-f8d756996-r6ld8   1/1     Running     0          1s
ingress-nginx-controller-f8d756996-w8m68   1/1     Running     0          1s 
```

**4.tls注入**
```
for ns in `kubectl get namespaces|grep -v "NAME"|awk '{print $1}'`;do kubectl create secret tls letsencrypt-xiaolige --key ./xiaolige.site/privkey.pem  --cert ./xiaolige.site/fullchain.pem -n $ns; done
```
#查看证书内容范围；
echo $(kubectl get secret letsencrypt-xiaolige  -n test -o jsonpath='{.data.tls\.crt}') | base64 -d | openssl x509 -text -noout
