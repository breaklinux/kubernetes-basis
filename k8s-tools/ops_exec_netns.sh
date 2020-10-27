#!'hin/bash
#author xiaolige
#desc enter contaniner nsenter and pod nsenter
function exec_pods() {
ns=$2
podName=$3
podID=`kubectl describe pod $podName -n $ns |grep -Eo 'docker://.*$' |sed 's/docker:\/\/\(.*\)$/\1/'`
for id in $podID
do
    dockerPid=`docker inspect -f {{.State.Pid}} $id`
    if [ -n $dockerPid ]
    then
       echo "enter pod netns successfully for $ns/$dockerPid"
       nsenter -n --target  $dockerPid  
    fi  
    
done
}

function exec_container() {
id=$2
dockerPid=`docker inspect -f {{.State.Pid}} $id`
if [[  $dockerPid -ne "" ]]
   then  echo "enter container netns successfully for $dockerPid" 
   nsenter -n --target  $dockerPid
else
    echo "chechk  container name or  container id"
fi      
}

case $1 in 
     "exec_pods_network")
     exec_pods $*
     ;;
     "exec_container_network")
     exec_container $*
     ;;     
    *)
       echo -e "\033[32m exec_pods_network namespaces名称 pod名称 \033[0m 进入pod网络调试,指定命名空间,pod名称"
       echo -e "\033[32m exec_container_network 容器名称  \033[0m 进入容器网络调试,指定容器名称或者容器ID"
     ;;
esac

