--[[
--	Description: the datas for autopeer
--	Athor: Moncak
--]]


--peerinfos
--Notice: all IP here are the tunnel IP
--when using this to init, all the peerinfos shloud be modified
--when using this to peer and not the first time using this, just modify the lines marked as "m"
OthersPeerInfo = {
    Peername = "abc",                                           --m
    ASN = "4211110000",                                         --m
    IP = "172.16.254.254",                                      --m
    PublicKey = "01234567890123456789012345678901234567890123", --m
    Endpoint = "example.com:23333",                             --m
}

--your PeerInfo, dont forget remove it when copy this script to others
YourPeerInfo = {
    ASN = "4211110001",
    PrivateKey = "01234567890123456789012345678901234567890123",
    PublicKey = "01234567890123456789012345678901234567890123",
    IP = "172.16.254.254",  
    Endpoint = "example.com",                                    
    Port = "23333",                                             --m
}

--If your conf is not at following palces,change it
Confs = {
    WGconf = string.format("/etc/wireguard/%s.conf", OthersPeerInfo.Peername),
    Birdconf = "/etc/bird.conf",
    WQOconf = "/etc/wg-quick-op.yaml",
    PUconf = "/etc/wireguard/port_using.log",
}

--just for test
--[[
Confs.WGconf = "wg0.conf"
Confs.Birdconf = "bird.conf"
Confs.WQOconf = "wg-quick-op.yaml"
Confs.PUconf = "port_using.log"
--]]
