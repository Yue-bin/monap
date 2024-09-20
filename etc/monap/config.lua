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
    Birdconf = "/etc/bird.conf",
    WQOconf = "/etc/wg-quick-op.yaml",
    PUconf = "/etc/wireguard/port_using.log",
    WGDic = "/etc/wireguard"
}

--just for test
---[[
os.execute("mkdir -p ./testconf")
ConfPaths.WGconf = "./testconf/wireguard/wg0.conf"
ConfPaths.Birdconf = "./testconf/bird.conf"
ConfPaths.WQOconf = "./testconf/wg-quick-op.yaml"
ConfPaths.PUconf = "./testconf/port_using.log"
ConfPaths.WGDic = "./testconf/wireguard"
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

-- config template
