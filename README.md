# monap

自动生成配置文件，作用域窄小的autopeer

目前来说，仅能用于 `dn11网络` 中as与as间peer

## 功能

* 追加配置文件并备份原配置文件
* 在第一次配置时初始化
* 生成发送给他人的本机的peerinfo
* 提供还原备份功能
* 脚本同时还会在 `/etc/wireguard/port_using.log` 中记录通过此脚本peer的端口

很多地方忽略了安全检查，是用后即弃的脚本

~~反正也只是自己用用够用就行~~

## 用法

```bash
Usage:

#第一次配置bird时初始化，非第一次peer无须执行
	#修改src/info.lua中所有的peerinfo
	lua init.lua	#这会删除你原本的bird.conf且不会备份

#追加配置文件并备份原配置文件
	#若非第一次使用，修改src/info.lua中被注释标记为 --m 的行
	lua monap.lua

#还原备份的配置文件
	lua restore.lua

#生成发送给他人的本机的peerinfo
	#第一次使用，修改src/info.lua中YourPeerInfo表的所有值
	#若非第一次使用，修改src/info.lua中YourPeerInfo表的被注释标记为 --m 的行
	lua genpeerinfo.lua

#其它用法，比如lua的命令行交互
	#eg:
	lua
	dofile("src/info.lua")
	dofile("src/functions.lua")
	GenBird()
	...
	#所有的函数存在src/functions.lua中

```
