***1.概述***
```
 通常web应用获取用户客户端的真实ip一个很常见的需求，例如将用户真实ip取到之后对用户做白名单访问限制、将用户ip记录到数据库日志中对用户的操作做审计等等
 在vm时代是一个比较容易解决的问题.但当一切云原生化（容器化）之后变得稍微复杂了些.
```


***2.背景k8s为什么无法直接获取client ip地址***
```
k8s中运行的应用通过Service抽象来互相查找、通信和与外部世界沟通，在k8s中是kube-proxy组件实现了Service的通信与负载均衡，流量在传递的过程中经过了源地址转换SNAT,
因此在默认的情况下，常常是拿不到用户真实的ip的
这个问题在k8s官方文档(https://kubernetes.io/zh/docs/tutorials/services/source-ip/)中基于Cluster IP、NodePort、LoadBalancer三种不同的Service类型进行了一定的说明，这里不再剖析
```


***3.nginx ingres 方式获取client-real-ip***
```
3.1.ngress Controller configmap配置 (试验版本:registry.k8s.io/ingress-nginx/controller:v1.4.0)
修改Nginx Ingress Controller配置，添加如下内容
参考：https://kubernetes.github.io/ingress-nginx/user-guide/

3.2 配置参数
data:
  use-forwarded-headers: "true"
  compute-full-forwarded-for: "true"
  forwarded-for-header: "X-Forwarded-For" 

#参数介绍
use-forwarded-headers #如果为true，会将传入的X-Forwarded-*头传递给upstreams 如果为false，会忽略传入的X-Forwarded-*头，用看到的请求信息填充它们。如果直接暴露在互联网上，或者它在基于L3/packet-based load balancer后面，并且不改变数据包中的源IP时使用此选项
forwarded-for-header #设置标头字段以标识客户端的原始IP地址。 默认: X-Forwarded-For
compute-full-forwarded-for #将远程地址附加到 X-Forwarded-For标头，而不是替换它。 启用此选项后，upstreams应用程序将根据其自己的受信任代理列表提取客户端IP
```

***4.测试获取客户端IP应用demo***

```
4.1 python flask应用

---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: op-python-real-ip  
  annotations:
    ingressclass.kubernetes.io/is-default-class: "true" 
spec:
  ingressClassName: nginx
  rules:
  - host: "op-python-real-ip.breaklinux.com"
    http:
      paths:
      - pathType: Prefix
        path: "/"
        backend:
          service:
            name: op-python-real-ip 
            port:
              number: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: op-python-real-ip
spec:
  selector:
    matchLabels:
      app: op-python-real-ip
  replicas: 1
  template:
    metadata:
      labels:
        app: op-python-real-ip
    spec:
      containers:
      - name: op-python-real-ip
        image: breaklinux/op-flask-api-get-x-real-ip:v2 
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: op-python-real-ip
spec:
  selector:
    app: op-python-real-ip 
  ports:
  - name: op-python-real-ip
    protocol: TCP
    port: 8080
    targetPort: 8080


4.2 java 应用
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: op-java-real-ip
  labels:
    app: op-java-real-ip
spec:
  selector:
    matchLabels:
      app: op-java-real-ip
  template:
    metadata:
      labels:
        app: op-java-real-ip
    spec:
      containers:
      - name: op-java-real-ip
        image: breaklinux/echoserver-get-x-real-ip:v1 
        ports:
        - containerPort: 8080
        env:
          - name: NODE_NAME
            valueFrom:
              fieldRef:
                fieldPath: spec.nodeName
          - name: POD_NAME
            valueFrom:
              fieldRef:
                fieldPath: metadata.name
          - name: POD_NAMESPACE
            valueFrom:
              fieldRef:
                fieldPath: metadata.namespace
          - name: POD_IP
            valueFrom:
              fieldRef:
                fieldPath: status.podIP

---
apiVersion: v1
kind: Service
metadata:
  name: op-java-real-ip
  labels:
    app: op-java-real-ip
spec:
  ports:
  - port: 80
    targetPort: 8080
    name: http
  selector:
    app: op-java-real-ip

---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: op-java-real-ip
  annotations:
    ingressclass.kubernetes.io/is-default-class: "true"  
spec:
  ingressClassName: nginx
  rules:
  - host: "op-java-real-ip.breakliniux.com"
    http:
      paths:
      - pathType: Prefix
        path: "/"
        backend:
          service:
            name: op-java-real-ip
            port:
              number: 80
```
****5.试验结果****
```
5.1 python 应用
[root@k8smaster ~]# curl op-java-real-ip.breaklinux.com/healthy -n
{"code": 200, "data": "healthy success", "clientIp": "192.168.1.7"}


5.2 java应用
[root@k8smaster ~]# curl op-java-real-ip.breakliniux.com
Hostname: echoserver-6f6d9d5f47-b4pjr
Pod Information:
	node name:	node
	pod name:	echoserver-6f6d9d5f47-b4pjr
	pod namespace:	dev
	pod IP:	10.244.0.47

Server values:
	server_version=nginx: 1.13.3 - lua: 10008

Request Information:
	client_address=10.244.0.1
	method=GET
	real path=/
	query=
	request_version=1.1
	request_scheme=http
	request_uri=op-java-real-ip.breakliniux.com:8080/

Request Headers:
	accept=*/*
	host=echo-ip.breakliniux.com
	user-agent=curl/7.77.0
	x-forwarded-for=192.168.1.4
	x-forwarded-host=op-java-real-ip.breakliniux.com
	x-forwarded-port=80
	x-forwarded-proto=http
	x-forwarded-scheme=http
	x-real-ip=192.168.1.4
	x-request-id=1fd464009eee61b6de2c703180de8991
	x-scheme=http

Request Body:
	-no body in request-

```
