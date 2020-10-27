from flask import Blueprint
from flask import request, Response
import json
devopsUrl = Blueprint('devops', __name__)
@devopsUrl.route('/api/v1', methods=['GET', 'POST'])
def devopsRun():
    if request.method == "GET":
        return devopsInfoSelect()
    else:
        parameterInfo = "请求不支持,请检查"
        return Response(json.dumps({"code": 1, "data": parameterInfo}), mimetype='application/json')

def devopsInfoSelect():
    parameterInfo = "request success"
    client = request.remote_addr
    return Response(json.dumps({"code": 0, "data": parameterInfo,"clientIp":client}), mimetype='application/json') 

@devopsUrl.route('/', methods=['GET', 'POST'])
def hello_worldRun():
    if request.method == "GET":
       parameterInfo = " hello world success"
       client = request.remote_addr
       return Response(json.dumps({"code": 0, "data": parameterInfo,"clientIp":client}), mimetype='application/json') 
    else:
       parameterInfo = "请求不支持,请检查"
       return Response(json.dumps({"code": 1, "data": parameterInfo}), mimetype='application/json')
