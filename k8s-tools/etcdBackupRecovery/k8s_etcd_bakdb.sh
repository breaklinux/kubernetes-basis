#!/bin/bash
function etcdDataBak(){
BACUPDIR="/chj/data/backup/etcd"
if [ ! -d "$BACUPDIR" ]; then
    echo "making dir $BACUPDIR"
    mkdir -p $BACUPDIR
fi
DATA=`date +%y%m%d`
if [ $1 = "dev" ]
then 
   ENDPOINTS='https://192.168.5.5:2379,https://192.168.5.6:2379,https://192.168.5.10:2379'
   timestamp=`date +%Y%m%d%H%M%S`
   env="dev"
elif [ $1 = "test" ]
then
   ENDPOINTS='https://192.168.6.1:2379,https://192.168.6.2:2379,https://192.168.6.3:2379'
   timestamp=`date +%Y%m%d%H%M%S`
   env="test"
else
   echo "xagrs There is no"
   exit 0
fi
certDir="/chj/data/backup/etcd/ssl/$env"
ENVBACUPDIR="/chj/data/backup/etcd/$env"
if [ ! -d "$ENVBACUPDIR" ]
then
  mkdir -p $ENVBACUPDIR
  ETCDCTL_API=3 etcdctl --endpoints=$ENDPOINTS  --cert=$certDir/etcd.pem  --key=$certDir/etcd-key.pem  --cacert=$certDir/ca.pem  snapshot save $ENVBACUPDIR/snapshot_$timestamp.db
else
   ETCDCTL_API=3 etcdctl --endpoints=$ENDPOINTS  --cert=$certDir/etcd.pem  --key=$certDir/etcd-key.pem  --cacert=$certDir/ca.pem  snapshot save $ENVBACUPDIR/snapshot_$timestamp.db
fi 

}

###清理备份策略#######
function clearData(){
delTime="7"
find $BACUPDIR -name *.db  -mtime +$delTime -exec rm -rf {} \;
}
if [ $# -ne 1 ]; then
    echo "Usage: $0 dev name"
else 
    etcdDataBak $*
    clearData 

fi
