ops-py-flask-api-dp-svc:
	kubectl apply -f ops-py-flask-api-v1.all.yaml
	kubectl apply -f ops-py-flask-api-v2.all.yaml

ops-nginx-ingress-01:
	kubectl apply -f ops-py-flask-api-ingres-01.yaml
ops-nginx-ingress-02:
	kubectl delete -f ops-py-flask-api-ingres-01.yaml
	kubectl apply -f ops-py-flask-api-ingres-02.yaml
# disallow any parallelism (-j) for Make. This is necessary since some
# commands during the build process create temporary files that collide
# under parallel conditions.
.NOTPARALLEL:

.PHONY: ops-py-flask-api-dp-svc ops-nginx-ingress-01
