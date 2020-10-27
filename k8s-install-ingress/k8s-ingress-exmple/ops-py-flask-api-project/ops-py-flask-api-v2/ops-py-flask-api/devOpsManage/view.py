from flask import Blueprint
from flask import request, Response
import json
import random
devopsUrl = Blueprint('devops', __name__)
@devopsUrl.route('/api/v2', methods=['GET', 'POST'])
def hello_worldRun():
    nber=random.randint(4,5)
    if request.method == "GET":
       parameterInfo = " hello world ops-py-flask-api-v2 success"
       return Response(json.dumps({"code": 0, "data": parameterInfo,"serialNumber":nber}), mimetype='application/json')     
    else:
       parameterInfo = "请求不支持,请检查"
       return Response(json.dumps({"code": 1, "data": parameterInfo}), mimetype='application/json')
