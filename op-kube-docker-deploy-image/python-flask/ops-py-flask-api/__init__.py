from flask import Flask
from devOpsManage.view  import devopsUrl
def create_app():
    app = Flask(__name__)
    app.register_blueprint(devopsUrl,url_prefix='/devops/')
    return app
