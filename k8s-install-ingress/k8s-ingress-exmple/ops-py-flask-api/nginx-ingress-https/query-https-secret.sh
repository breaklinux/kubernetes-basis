#!/bin/bash
#注入cecret
#证书认证注入管理员权限
for ns in `kubectl get namespaces|grep -v "NAME"|awk '{print $1}'`;do kubectl create secret tls letsencrypt-https --key ./certbot/config-dir/live/xiaolige.com/privkey.pem  --cert ./certbot/config-dir/live/xiaolige.com/fullchain.pem -n $ns; done
 

#查询secret 证书详细信息
echo $(kubectl get secret letsencrypt-xiaolige-site  -n devops-python -o jsonpath='{.data.tls\.crt}')| base64 -d|openssl x509 -text -noout  
