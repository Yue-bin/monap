# monap

autopeer by moncak

> [!WARNING]
>
> 非严格意义上的autopeer，只是一个简单的peer工具箱

~~有人写完才知道autopeer是什么我不说是谁~~

自动生成配置文件，作用域窄小的autopeer

目前来说，仅能用于 `DN11` 中as与as间使用BGP和wireguard进行的peer

**本脚本仅用于辅助，使用前请确保阅读[DN11Wiki](https://dn11.top/)并以其为准**

## 功能

* 根据配置文件里的信息生成发送给别人的peerinfo
* 根据输入的peerinfo自动生成和修改相关的配置文件并执行 `wg-quick-op up <name>`和 `birdc configure`

  * 并添加接口到指定的防火墙区域或者 `dn11`或 `vpn`区域
  * 以及对输入的peerinfo进行一些基本的检查
  * TODO: 更加智能的peerinfo识别，JSON格式peerinfo输入输出
* (部分)支持旧版使用 `wg-quick-op.yaml`配置文件的 `wg-quick-op`

  *新版可以直接忽略了所以就直接抄了旧版的代码也懒得维护*
* 显示某个连接的相关信息

  *其实就是打印 `wg show <name>`和 `birdc show protocol <name>`但是可以一起watch诶不香吗）*
* 显示所有已经被使用的端口

  *貌似 `wg-quick-op`支持来着但是我忘记是什么了就）*
* 按照配置文件给定的 `PortGenMethod`和正在使用中的端口自动选择新使用的端口

  也可手动使用 `-p`或 `--port`指定

  **当不存在正在使用的端口的时候必须手动指定**
* 提供还原备份功能
* 安装与卸载，可以指定可选的 `--prefix`参数
* TODO: 检查连接，自动化排障

## 用法

```bash
monap is a script for autopeer
Usage: monap [COMMAND] [NAME] [OPTIONS]
    Commands:
        info: genarate the peerinfo
        peer: peer with others
        restore: restore the config file save by monap
        test: test the connection
        show: show the status of the connection
        showport: show the port in use
        install: install the monap and config file
        uninstall: remove the monap and (optional) config file
    NAME:
        the name of the peer
    Options:
        -v, --version: output version information and exit
        -h, --help: output this help information and exit
        -q, --quiet: quiet mode
        -c, --config <config-file>: specify the config file
        -i, --info <info-str>: the info string genarated by info command
        --suffix <suffix>: specify the suffix of the backup file (default: bak)
        --prefix <prefix>: specify the prefix of the install path (default: /)
        --log-level <level>: specify the log level
            Loglevels: DEBUG INFO WARN ERROR FATAL
        -p, --port <port>: specify the port
        --fwmark <fwmark>: specify the fwmark (default: none)
        --mtu <mtu>: specify the mtu (default: 1388)
        --keepalive <keepalive>: specify the keepalive (default: none)
        --no-bird: do not operate bird and config file of bird
        --no-wg: do not operate wireguard and config file of wireguard
        --old-wg-quick-op: use the config file wg-quick-op.yaml
```

其中peerinfo的示例如下：

```
Peerinfos:
        ASN:4211110001
        IP:172.16.254.254
        Endpoint:example.com:12345
        PublicKey:01234567890123456789012345678901234567890123
```

但是事实上只需要包含以下的必须字段：

```
ASN:4211110001
IP:172.16.254.254
PublicKey:01234567890123456789012345678901234567890123
```

DEMO：

```shell
╰─± git clone https://github.com/Yue-bin/monap
	...

╰─± ./monap.lua install
[INFO] config file found: ./etc/monap/config.lua
[INFO] installing monap to /usr/bin/monap
[INFO] installing ./etc/monap/config.lua to /etc/monap/config.lua

╰─± monap uninstall
[INFO] config file found: /etc/monap/config.lua
[INFO] removing monap from /usr/bin/monap
Do you want to remove the config file? [y/N]: y
[INFO] removing config.lua from /etc/monap/config.lua

╰─± monap info -p 12345
[INFO] config file found: /etc/monap/config.lua
Peerinfos:
        ASN:4211110001
        IP:172.16.254.254
        Endpoint:example.com:12345
        PublicKey:01234567890123456789012345678901234567890123

╰─± monap peer moncak -p 12345 -i "Peerinfos:
        ASN:4211110001
        IP:172.16.254.254
        Endpoint:example.com:35018 
        PublicKey:0123456789123456789012345678901234567890123"
[INFO] config file found: /etc/monap/config.lua
[WARN] PublicKey length is not 44 , but 43
[INFO] peer with moncak with info
[INFO] ASN: 4211110001
[INFO] IP: 172.16.254.254
[INFO] Endpoint: example.com:35018
[INFO] PublicKey: 0123456789123456789012345678901234567890123
if the peer info is correct, press any key to continue, or press Ctrl+C to exit

[INFO] generating wireguard config file
[INFO] up the wireguard interface
[INFO] modifying bird config file
[INFO] reconfiguring bird
```

## 依赖

~~hundred の hundred percents in lua official(x~~

代码主体完全基于Lua的官方库

相关操作需要有 `bird2`,`birdc2`,`wg-quick-op`支持

防火墙操作需要有 `uci`支持

总体来说现在基本是非 `OpenWrt`不行了

*`OpenWrt`自带lua5.1用于提供luci所以完美支持的说*

## 杂项

非单用户系统使用记得妥善管理 `<prefix>/etc/monap/config.lua`的写权限，因为我没有做防鸿儒处理所以可以直接在 `config.lua`中注入lua语句

*反正OP默认就一个root谁管他(x*

## 感谢

本项目参考了以下项目：

[luci-network-dn11](https://github.com/dn-11/luci-network-dn11)
