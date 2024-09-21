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
---[[
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
LOG_LEVEL = Loglevels.DEBUG

-- port genarating method
-- +: add 1 to the max inuse port
-- -: sub 1 to the min inuse port
PortGenMethod = "+"

-- use old wg-quick-op conf
-- dont use it with new version wg-quick-op with conf wg-quick-op.toml
-- OldWGOconf = true

-- config templates
-- wg conf template
-- 干李良的lua的语法糖忽略[[后第一个换行符我还得手动加上去
function GenWGConf(peerinfo, port)
    local conf = [[
[Interface]
PrivateKey = ]] .. YourPeerInfo.PrivateKey .. [[\n
ListenPort = ]] .. port .. [[\n
PostUp = /sbin/ip addr add dev %i ]] .. YourPeerInfo.IP .. [[/32 peer ]] .. peerinfo.IP .. [[/32
Table = off
MTU = 1388

]] .. "[Peer]"
    --if Endpoint is not empty, add it
    if peerinfo.Endpoint ~= "" then
        conf = conf .. "Endpoint = " .. peerinfo.Endpoint
    end
    conf = conf .. [[\n
PublicKey = ]] .. peerinfo.PublicKey .. [[\n
AllowedIPs = 10.0.0.0/8,100.64.0.0/10,172.16.0.0/12,192.168.0.0/16
    ]]
    return conf
end

-- bird conf template
function GenBirdConf(name, peerinfo)
    conf = [[
protocol bgp ]] .. name .. [[ from BGP_peers {
    neighbor ]] .. peerinfo.IP .. [[%]] .. name .. [[ as ]] .. peerinfo.ASN .. [[;
}]]
    return conf
end
