FROM python:3.6.8 As builder

WORKDIR /xiaolige/app/ops-py-flask-api/
COPY requirements.txt .
RUN pip install -i https://pypi.tuna.tsinghua.edu.cn/simple -r requirements.txt

FROM python:3.6.8-alpine3.8

COPY --from=builder /usr/local/lib/python3.6/site-packages /usr/local/lib/python3.6/site-packages

# Set 阿里云软件更新源
RUN   sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories && \
apk add --no-cache tzdata &&  apk add curl && \
ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
echo $TZ > /etc/timezone && mkdir -p /xiaolige/app && chmod 775 -R /xiaolige

ENV TZ=Asia/Shanghai LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
EXPOSE 6000
WORKDIR /xiaolige/app/
COPY ops-py-flask-api .
HEALTHCHECK --interval=5s --timeout=3s CMD curl http://localhost:6000/devops/api/v2 || exit 1
CMD ["python","boot.py"]
