# monap

自动生成配置文件，作用域窄小的autopeer

目前来说，仅能用于 `dn11网络` 中as与as间peer
且仅能追加配置文件并备份原配置文件

提供还原备份功能

很多地方也忽略了安全检查，是用后即弃的脚本

~~反正也只是自己用用够用就行~~

```bash
Usage:

#追加配置文件并备份原配置文件
	#修改peerinfo.lua中被注释标记为 `--m` 的行
	lua monap.lua

#还原备份的配置文件
	lua restore.lua
```

脚本同时还会在 `/etc/wireguard/port_using.log` 中记录通过此脚本peer的端口
