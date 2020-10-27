FROM python:3.6.8

RUN pip install --upgrade pip

COPY requirements.txt .
RUN pip install -i https://pypi.tuna.tsinghua.edu.cn/simple -r requirements.txt
