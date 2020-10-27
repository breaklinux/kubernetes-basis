OPS_FLASK_api_V1_TAG?=harbor.xiaolige.site/k8s/ops-py-flask-api:v1
OPS_FLASK_api_V2_TAG?=harbor.xiaolige.site/k8s/ops-py-flask-api:v2

ops-py-flask-api-v1:
	docker build -t $(OPS_FLASK_api_V1_TAG) ./ops-py-flask-api-v1
	docker push $(OPS_FLASK_api_V1_TAG)

ops-py-flask-api-v2:
	docker build -t $(OPS_FLASK_api_V2_TAG) ./ops-py-flask-api-v2
	docker push $(OPS_FLASK_api_V2_TAG)

# disallow any parallelism (-j) for Make. This is necessary since some
# commands during the build process create temporary files that collide
# under parallel conditions.
.NOTPARALLEL:

.PHONY: ops-py-flask-api-v1  ops-py-flask-api-v2 
