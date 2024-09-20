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
    Endpoint = "example.com",
    Port = "23333", --m
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

LOG_LEVEL = Loglevels.DEBUG

-- config template
