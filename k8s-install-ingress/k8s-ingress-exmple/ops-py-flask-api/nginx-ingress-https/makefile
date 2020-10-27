create-xiaolige-secret:
	kubectl create secret tls letsencrypt-xiaolige-site --key=./cert/xiaolige-privkey.pem --cert=./cert/xiaolige.pem -n devops-python
create-xiaolige-https-ingress:
	kubectl apply -f ops-py-flask-api-ingres-02-https.yaml
.NOTPARALLEL:

.PHONY: create-xiaolige-secret create-xiaolige-https-ingress 
