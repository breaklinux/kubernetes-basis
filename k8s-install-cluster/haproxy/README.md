**1.部署haproxy 服务**
```
yum -y install epel-release haproxy-1.5.18
```
**2.设置配置文件**
```
mkdir /usr/share/doc/haproxy-1.5.18/conf/

cat <<EOF > /usr/share/doc/haproxy-1.5.18/conf/haproxy.cfg
global
    log         127.0.0.1 local2
    chroot      /var/lib/haproxy
    pidfile     /var/run/haproxy.pid
    maxconn     40000
    user        haproxy
    group       haproxy
    daemon
    stats socket /var/lib/haproxy/stats
defaults
    mode                    http
    log                     global
    option                  dontlognull
    option http-server-close
    option                  redispatch
    retries                 3
    timeout http-request    10s
    timeout queue           1m
    timeout connect         10s
    timeout client          30s
    timeout server          30s
    timeout http-keep-alive 60s
    timeout check           5s
    maxconn                 10000
listen k8s-api-server-4level
    bind *:6443
    mode tcp
    balance roundrobin
    timeout client          4h
    timeout server          4h
    timeout connect         10s
    timeout check           10s
    maxconn                 3000
    server k8s-master-1 192.168.1.1 check port 6443 inter 5000 fall 5
    server k8s-master-2 192.168.1.2 check port 6443 inter 5000 fall 5
    server k8s-master-3 192.168.1.3 check port 6443 inter 5000 fall 5
listen k8s-ingress-80-4level
    bind *:80
    mode tcp
    balance roundrobin
    server s1 192.168.1.1:30333 weight 1 maxconn 10000 check inter 3s
    server s1-ingress  192.168.1.2:30333  weight 1 maxconn 10000 check inter 3s
    server s1-ingress  192.168.1.3:30333 weight 1 maxconn 10000 check inter 3s
listen k8s-ingress-443-4level
    bind *:443
    mode tcp
    balance roundrobin
    server s1 192.168.1.1:30334  weight 1 maxconn 10000 check inter 3s
    server s1-ingress2 192.168.1.2:30334 weight 1 maxconn 10000 check inter 3s
    server s1-ingress3 192.168.1.3:30334 weight 1 maxconn 10000 check inter 3s
EOF
```
**3.服务启动**
/usr/sbin/haproxy -f /usr/share/doc/haproxy-1.5.18/conf/haproxy.cfg -sf 24752

**4.域名泛解析**


