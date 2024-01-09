# monap

自动生成配置文件，作用域窄小的autopeer

目前来说，仅能用于 `dn11网络` 中as与as间peer
且仅能追加配置文件

很多地方也忽略了安全检查，是用后即弃的脚本

~~反正也只是自己用用够用就行~~


Usage:

    修改被注释标记为`-m` 的行

    `lua monap.lua`


脚本同时还会在 `/etc/wireguard/port_using.log` 中记录使用的端口
