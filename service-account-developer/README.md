 
**1.RBAC 由来**
```
例如:
1.你要通过一个外部插件，在 Kubernetes 里新增和操作API对象，那么就必须先了解一个非常重要的知识：RBAC

我们知道，Kubernetes 中所有的 API 对象，都保存在 Etcd 里。可是，对这些 API 对象的操作，却一定都是通过访问 kube-apiserver 实现的。其中一个非常重要的原因，就是你需要 APIServer 来帮助你做授权工作。
```


**2.Kubernetes RBAC用途**
```
在 Kubernetes 项目中，负责完成授权（Authorization）工作的机制，就是 RBAC：基于角色的访问控制（Role-Based Access Control）
```

***3.RBAC核心概念***

****3.1 namespace范围****

- Role：角色，它其实是一组规则，定义了一组对 Kubernetes API 对象的操作权限。
- Subject：被作用者，既可以是“人”，也可以是“机器”，也可以是你在 Kubernetes 里定义的“用户”。
- RoleBinding：定义了“被作用者”和“角色”的绑定关系。

****3.2 cluster范围比如:node,网络插件,ingress等****

- ClusterRole:角色，它其实是一组规则，定义了一组对 Kubernetes API 对象的操作权限。
- ClusterRoleBinding:定义了“被作用者”和“角色”的绑定关系。
- ServiceAccount: Kubernetes 里"内置用户"


***4.ServiceAccount 概述** 
```
而正如我前面介绍过的，在大多数时候，我们其实都不太使用“用户”这个功能，而是直接使用 Kubernetes 里的“内置用户”。
```

**5.缺省配置**
```
缺省配置
为所有 Namespace 下的默认 ServiceAccount 绑定一个只读权限的 Role。

如果一个 Pod 没有声明 ServiceAccount，k8s 会自动在它的 Namespace 下创建一个名叫 default 的默认 ServiceAccount，然后分配给这个 Pod。

但是这个默认 ServiceAccount 并没有关联任何 Role，因此有访问 APIServer 的绝大多数权限。为了避免风险，需要对默认 ServiceAccount 的权限做限制。
```


***6.k8s 认证方式流程**

***6.1 认证方式***
```
本地端的Apiserver，control managent和Schedule监听的是本地的非安全端口，则不要任何认证，就拥有最大的权限，但是这个端口之只能运行再本地

node的kubelet和Apiserver的认证：apiserver再启动的时候会生成一个token文件，kubelet第一次连接的时候是基于token的，默认的用户是bootstrp-kubelet带着token访问apiserver，apiserver就会签发证书，再kubelet.kubeconfig文件定义
```

***6.2认证插方式***

apiserver和kubeproxy的认证：

- X509证书
```
使用X509客户端证书只需要API Server启动时配置--client-ca-file=SOMEFILE。在证书认证时，其CN域用作用户名，而组织机构域则用作group名。
静态Token文件
```

-  使用静态Token文件认证只需要API 
```
Server启动时配置--token-auth-file=SOMEFILE。
该文件为csv格式，每行至少包括三列token,username,user id，token,user,uid,"group1,group2,group3”
引导Token
引导Token是动态生成的，存储在kube-system namespace的Secret中，用来部署新的Kubernetes集群。
使用引导Token需要API Server启动时配置--experimental-bootstrap-token-auth，并且Controller Manager开启TokenCleaner --controllers=*,tokencleaner,bootstrapsigner。
在使用kubeadm部署Kubernetes时，kubeadm会自动创建默认token，可通过kubeadm token list命令查询。
```
- 静态密码文件

```
需要API Server启动时配置--basic-auth-file=SOMEFILE，文件格式为csv，每行至少三列password, user, uid，后面是可选的group名，如
password,user,uid,"group1,group2,group3”
Service Account

ServiceAccount是Kubernetes自动生成的，并会自动挂载到容器的/run/secrets/kubernetes.io/serviceaccount目录中。
OpenID
```

- OAuth2的认证机制

```
OpenStack Keystone密码
需要API Server在启动时指定--experimental-keystone-url=<AuthURL>，而https时还需要设置--experimental-keystone-ca-file=SOMEFILE。
匿名请求

如果使用AlwaysAllow以外的认证模式，则匿名请求默认开启，但可用--anonymous-auth=false禁止匿名请求。
Kubernetes认证帐户
```

***6.3 Kubernetes认证帐户***

- USER帐户给管理人员使用，SERVICEACCOUNT是给POD里的进程使用的。

- USER帐户是全局性的，Service Account属于某个namespace
- Group用来关联多个帐户，集群中有一些默认创建的组，如cluster-admin

- Service Account

```
1. Service account是为了方便Pod里面的进程调用Kubernetes API或其他外部服务而设计的。它与User account不同
2.User account是为人设计的，而service account则是为Pod中的进程调用Kubernetes API而设计；
3.User account是跨namespace的，而service account则是仅局限它所在的namespace；
4.每个namespace都会自动创建一个default service account
5.Token controller检测service account的创建，并为它们创建secret
6.开启ServiceAccount Admission Controller后
7.每个Pod在创建后都会自动设置spec.serviceAccountName为default（除非指定了其他ServiceAccout）
8.验证Pod引用的service account已经存在，否则拒绝创建
9.如果Pod没有指定ImagePullSecrets，则把service account的ImagePullSecrets加到Pod中
10.每个container启动后都会挂载该service account的token和ca.crt到/var/run/secrets/kubernetes.io/serviceaccount/
```

默认的认证是基于证书的双向认证，再创建一个K8S集群，会默认创建一系列证书


**7.生成客户端证书**
```
# 生成 2048 位的私钥
openssl genrsa -out k8s-developer-devops-python.key 2048 
# 生成证书签发请求
# CN 需要和 ServiceAccount 对应的用户名保持一致
openssl req -new -key  k8s-developer-devops-python.key -out k8s-developer-devops-python.csr -subj "/CN=system:serviceaccount:default:k8s-developer-devops-python/O=default"
 
 
# 利用 CA 证书私钥签发证书
# 注意设定合理的过期时间
openssl x509 -req -in k8s-developer-devops-python.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out k8s-developer-devops-python.crt -days 10000
 
 
# 验证生成证书的合法性
openssl x509  -noout -text -in ./k8s-developer-devops-python.crt
 
#把用户账户信息添加到当前集群中,embed-certs=true隐藏证书信息
 kubectl config set-credentials k8s-developer-devops-python --client-certificate=k8s-developer-devops-python.crt --client-key=k8s-developer-devops-python.key --embed-certs=true
 
#设置该用户可以访问kubernetes集群
 kubectl config set-context k8s-developer-devops-python@kubernetes --cluster=kubernetes --user=k8s-developer-devops-python
 
## 切换到用户k8s-developer-dev,登录k8s,可以看到用户k8s-developer-dev没有管理器权限
kubectl config use-context k8s-developer-devops-python@kubernetesqu
##授权集群token方式访问
kubens default

SERVICE_ACCOUNT="k8s-developer-devops-python"

SECRET=$(kubectl get serviceaccount ${SERVICE_ACCOUNT} -o json | jq -Mr '.secrets[].name | select(contains("token"))')

TOKEN=$(kubectl get secret ${SECRET} -o json | jq -Mr '.data.token' | base64 -D)
echo $TOKEN

#客户端命令测试
curl -s https://192.168.1.1:6443/api/v1  --header "Authorization: Bearer $TOKEN" --cacert ~/Downloads/Desktop/ca.crt
```



**8.ServiceAccount 用户的权限规划适用用于整个集群.**

  serviceAccount/name   |User/name |权限|用途
  -|-|-|-
  default       |system.serviceaccount.default.default |只读，不包含集群、保密字典|应用 Pod
  developer     |system.serviceaccount.default.developer |只读，不包含集群、保密字典| 开发人员接入k8s
  user-ops      |system.serviceaccount.default.user-ops |只有集群只读权限，无角色/权限管理权，有其他的所有权限| 运维人员接入 k8s
  user-cluster-admin  |system.serviceaccount.default.user-cluster-admin | 超级管理员|兜底   

