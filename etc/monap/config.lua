--[[
--	Description: the datas for autopeer
--	Athor: Moncak
--]]

--peerinfos
--Notice: all IP here are the tunnel IP
--your PeerInfo, dont forget remove it when copy this script to others
YourPeerInfo = {
    ASN = "4211110001",
    PrivateKey = "01234567890123456789012345678901234567890123",
    PublicKey = "01234567890123456789012345678901234567890123",
    IP = "172.16.254.254",
    IPSegment = "172.16.254.1/24",
    Endpoint = "example.com"
}

--If your conf is not at following palces,change it
ConfPaths = {
    WGconf_str = "/etc/wireguard/%s.conf",
    --Birdconf = "/etc/bird.conf",
    Birdconf = "/etc/bird/bgp.conf", -- 这玩意指向你的bgp在的bird配置文件
    WQOconf = "/etc/wg-quick-op.yaml",
}

--just for test
--[[
os.execute("mkdir -p ./testconf/wireguard")
--ConfPaths.WGconf_str = "./testconf/wireguard/%s.conf"
ConfPaths.Birdconf = "./testconf/bird.conf"
ConfPaths.WQOconf = "./testconf/wg-quick-op.yaml"
--]]
--YourPeerInfo = nil

--[[
-- log levels
    DEBUG
    INFO
    WARN
    ERROR
    FATAL
--]]
LOG_LEVEL = Loglevels.INFO

-- port genarating method
-- +: add 1 to the max inuse port
-- -: sub 1 to the min inuse port
PortGenMethod = "+"

-- use old wg-quick-op conf
-- dont use it with new version wg-quick-op with conf wg-quick-op.toml
-- OldWGOconf = true
OldWGOconf = false

-- config templates
-- 对于每一个<foo>,如果对应的foo存在于替换列表中,都会被替换为foo对应的值
-- 每一个模版都会提供一个替换列表
-- 前面带有#的行是可选项，如果在使用中没有明确指定或者为空的话，会被忽略
-- 即以注释的形式写入文件

-- wg conf template
--[[
    替换列表:
        <pri_key> : 你的私钥
        <port> : 你的端口
        <local_ip> : 你的本地隧道IP
        <peer_ip> : 你的对端隧道IP
        <mtu> : 接口的MTU
        <fwmark> : 防火墙标记
        <endpoint> : 对端的地址
        <pub_key> : 你的公钥
        <keepalive> : 保持活跃时间
]]
WGConfT = [[
[Interface]
PrivateKey = <pri_key>
ListenPort = <port>
PostUp = /sbin/ip addr add dev %i <local_ip>/32 peer <peer_ip>/32
# PostUp = wg set %i fwmark <fwmark>
Table = off
MTU = <mtu>

[Peer]
# Endpoint = <endpoint>
PublicKey = <pub_key>
AllowedIPs = 10.0.0.0/8,100.64.0.0/10,172.16.0.0/12,192.168.0.0/16
# PersistentKeepalive = <keepalive>
]]

-- bird conf template
--[[
    替换列表:
        <name> : 你的隧道名称以及bird的实例名称
        <peer_ip> : 对端的隧道IP
        <asn> : 对端的ASN
]]
BirdConfT = [[
protocol bgp <name> from BGP_peers {
    neighbor <peer_ip>%<name> as <asn>;
}
]]
