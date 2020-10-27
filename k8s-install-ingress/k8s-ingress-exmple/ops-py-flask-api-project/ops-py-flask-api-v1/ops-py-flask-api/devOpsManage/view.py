from flask import Blueprint
from flask import request, Response
import json
import random
devopsUrl = Blueprint('devops', __name__)
@devopsUrl.route('/api/v1', methods=['GET', 'POST'])
def hello_worldRun():
    nber=random.randint(1,3)
    if request.method == "GET":
       parameterInfo = " hello world ops-py-flask-api-v1 success" 
       return Response(json.dumps({"code": 0, "data": parameterInfo,"serialNumber":nber}), mimetype='application/json') 
    else:
       parameterInfo = "请求不支持,请检查"
       return Response(json.dumps({"code": 1, "data": parameterInfo}), mimetype='application/json')
