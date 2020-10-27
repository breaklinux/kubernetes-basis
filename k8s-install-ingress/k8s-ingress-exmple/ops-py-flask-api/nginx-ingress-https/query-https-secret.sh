#!/bin/bash
#查询secret 证书详细信息
echo $(kubectl get secret letsencrypt-xiaolige-site  -n devops-python -o jsonpath='{.data.tls\.crt}')| base64 -d|openssl x509 -text -noout  
