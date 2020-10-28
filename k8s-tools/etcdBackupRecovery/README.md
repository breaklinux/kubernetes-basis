***一、备份***
```
此备份方式是借助 etcd的snapshot功能做备份，需要时可以把etcd集群回滚到具体备份的时间点，此备份是基于etcd api 3版本的备份，如果数据是用api 2版本写入的，则api 2版本写入的数据无法恢复
1、备份命令
ETCDCTL_API=3 etcdctl --endpoints="https://192.168.1.1:2379"  --cert=/etc/etcd/ssl/etcd.pem  --key=/etc/etcd/ssl/etcd-key.pem  --cacert=/etc/etcd/ssl/ca.pem  snapshot save /chj/backup/etcd3/snapshot.db
```
***二、恢复***
此恢复方案是基于快照的备份做恢复，恢复的时候需要停止etcd集群把备份的快照文件恢复到集群的数据目录，或者可以新建一个etcd集群，把备份的快照恢复到新集群

1、停止所有节点的服务

systemctl stop etcd
2、把当前数据目录备份

mv /var/lib/etcd /var/lib/etcd_bak_20190523
3、确认需要回滚的快照文件，分布还原到集群的每个节点上

```
还原192.168.1.3节点
ETCDCTL_API=3 etcdctl --name=k8stest-master-1.com --endpoints="https://192.168.1.3:2379" --cert=/etc/etcd/ssl/etcd.pem  --key=/etc/etcd/ssl/etcd-key.pem  --cacert=/etc/etcd/ssl/ca.pem --initial-cluster-token=etcd-cluster-0 --initial-advertise-peer-urls=https://192.168.1.3:2380 --initial-cluster=k8stest-master-1.chj.cloud=https://192.168.1.3:2380,k8stest-master-2.com=https://192.168.1.2:2380,k8stest-master-3.com=https://192.168.1.1:2380 --data-dir=/var/lib/etcd snapshot restore /chj/backup/etcd3/snapshot.db

还原192.168.1.2节点
ETCDCTL_API=3 etcdctl --name=k8stest-master-2.chj.cloud --endpoints="https://192.168.1.2:2379" --cert=/etc/etcd/ssl/etcd.pem  --key=/etc/etcd/ssl/etcd-key.pem  --cacert=/etc/etcd/ssl/ca.pem --initial-cluster-token=etcd-cluster-0 --initial-advertise-peer-urls=https://192.168.1.2:2380 --initial-cluster=k8stest-master-1.chj.cloud=https://192.168.1.3:2380,k8stest-master-2.com=https://192.168.1.2:2380,k8stest-master-3.com=https://192.168.1.1:2380 --data-dir=/var/lib/etcd snapshot restore /chj/backup/etcd3/snapshot.db

还原192.168.1.1节点
ETCDCTL_API=3 etcdctl --name=k8stest-master-3.chj.cloud --endpoints="https://192.168.1.1:2379" --cert=/etc/etcd/ssl/etcd.pem  --key=/etc/etcd/ssl/etcd-key.pem  --cacert=/etc/etcd/ssl/ca.pem --initial-cluster-token=etcd-cluster-0 --initial-advertise-peer-urls=https://192.168.1.1:2380 --initial-cluster=k8stest-master-1.com=https://192.168.1.3:2380,k8stest-master-2.com=https://192.168.1.2:2380,k8stest-master-3.com=https://192.168.1.1:2380 --data-dir=/var/lib/etcd snapshot restore /chj/backup/etcd3/snapshot.db
```
***三、常用命令***
```
使用API 3写入数据

ETCDCTL_API=3 etcdctl --endpoints="https://192.168.1.3:2379,https://192.168.1.2:2379,https://192.168.1.1:2379" --cert=/etc/etcd/ssl/etcd.pem  --key=/etc/etcd/ssl/etcd-key.pem  --cacert=/etc/etcd/ssl/ca.pem   put /chj/3 api3
使用API 3读数据

ETCDCTL_API=3 etcdctl --endpoints="https://192.168.1.3:2379,https://192.168.1.2:2379,https://192.168.1.1:2379" --cert=/etc/etcd/ssl/etcd.pem  --key=/etc/etcd/ssl/etcd-key.pem  --cacert=/etc/etcd/ssl/ca.pem   get  /chj/3
使用API 3 查看所有key

ETCDCTL_API=3 etcdctl --endpoints="https://192.168.1.3:2379,https://192.168.1.2:2379,https://192.168.1.1:2379" --cert=/etc/etcd/ssl/etcd.pem  --key=/etc/etcd/ssl/etcd-key.pem  --cacert=/etc/etcd/ssl/ca.pem   get / --prefix --keys-only
使用API 3 删除所有key

ETCDCTL_API=3 etcdctl --endpoints="https://192.168.1.3:2379,https://192.168.1.2:2379,https://192.168.1.1:2379" --cert=/etc/etcd/ssl/etcd.pem  --key=/etc/etcd/ssl/etcd-key.pem  --cacert=/etc/etcd/ssl/ca.pem   del "" --prefix
查看集群成员

ETCDCTL_API=3 etcdctl --endpoints="https://192.168.1.3:2379,https://192.168.1.2:2379,https://192.168.1.1:2379" --cert=/etc/etcd/ssl/etcd.pem  --key=/etc/etcd/ssl/etcd-key.pem  --cacert=/etc/etcd/ssl/ca.pem   member list --write-out=table   
查看集群健康状态

ETCDCTL_API=3 etcdctl --endpoints="https://192.168.1.3:2379,https://192.168.1.2:2379,https://192.168.1.1:2379" --cert=/etc/etcd/ssl/etcd.pem  --key=/etc/etcd/ssl/etcd-key.pem  --cacert=/etc/etcd/ssl/ca.pem   endpoint health 
查看节点状态

ETCDCTL_API=3 etcdctl --endpoints="https://192.168.1.3:2379,https://192.168.1.2:2379,https://192.168.1.1:2379" --cert=/etc/etcd/ssl/etcd.pem  --key=/etc/etcd/ssl/etcd-key.pem  --
```
