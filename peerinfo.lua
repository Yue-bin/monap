--[[
--	Description: the datas for autopeer
--	Athor: Moncak
--]]

--when using this to peer, just modify the lines marked as "m"
OthersPeerInfo = {
    Peername = "abc",                                           --m
    ASN = "4211110000",                                         --m
    IP = "172.16.254.254",                                      --m
    PublicKey = "01234567890123456789012345678901234567890123", --m
    Endpoint = "example.com:23333",                             --m
}

--your PeerInfo, dont forget remove it when copy this script to others
YourPeerInfo = {
    PrivateKey = "01234567890123456789012345678901234567890123",
    IP = "172.16.254.254",
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


--Help functions
--Test if the given file is exists
function TestFile(file)
    local f=io.open(file, "r")
    if f~=nil then 
        io.close(f) 
        return true 
    else 
        return false 
    end
end