**1.kube-proxy-三种工作模式**
```
1.userspace 用户空间发生两次用户态到内核态切换,性能较差
2.iptables  默认模式-->工作内核态随着service的规则变多iptables规则匹配效率较低
3.ipvs 模式 工作在内核态减少规则匹配.
```
**2.开启kube-ipvs工作模式流程**
```
1.添加内核参数---->修改kube-proxy配置文件-->验证ipvs功能是否正常开启

```
**3.脚本功能介绍**
```
 bash kube-proxy-cluster-ipvs.sh 
 参数如下: 
 load_ipvs_module  系统内核加载支持ipvs模块
 view_ipvs  验证系统节点开启ipvs模块
 config_ipvs_Model  设置kube_proxy_ipvs模式
 graceful_restart  滚动重启kube-proxy
 all  配置ipvs所有功能
```

