--[[
--	Description: a script for autopeer
--	Athor: Moncak
--]]

--when using this to peer, just modify the lines marked as "m"
OthersPeerInfo = {}
OthersPeerInfo.Peername = "abc"                                           --m
OthersPeerInfo.ASN = "4211110000"                                         --m
OthersPeerInfo.IP = "172.16.254.254"                                      --m
OthersPeerInfo.PublicKey = "01234567890123456789012345678901234567890123" --m
OthersPeerInfo.Endpoint = "example.com:23333"                             --m

--your PeerInfo, dont forget remove it when copy this script to others
YourPeerInfo = {}
YourPeerInfo.PrivateKey = "01234567890123456789012345678901234567890123"
YourPeerInfo.IP = "172.16.254.254"
YourPeerInfo.Port = "23333" --m

--If your conf is not at following palces,change it
WGconf = string.format("/etc/wireguard/%s.conf", OthersPeerInfo.Peername)
Birdconf = "/etc/bird.conf"
WQOconf = "/etc/wg-quick-op.yaml"
PUconf = "/etc/wireguard/port_using.log"

--TODO:加入文件指针判空
--算了其实出错的话lua自己会大声告诉你的

--Generate conf of wireguard
function GenWg()
    local conf = io.open(WGconf, "w")
    conf:write("[Interface]\n",
        "PrivateKey = ", YourPeerInfo.PrivateKey, "\n",
        "ListenPort = ", YourPeerInfo.Port, "\n",
        "PostUp = /sbin/ip addr add dev %i ", YourPeerInfo.IP, "/32 peer ", OthersPeerInfo.IP, "/32\n",
        "Table = off\n",
        "MTU = 1420\n",
        "\n",
        "[Peer]\n",
        "Endpoint = ", OthersPeerInfo.Endpoint, "\n",
        "PublicKey = ", OthersPeerInfo.PublicKey, "\n",
        "AllowedIPs = 0.0.0.0/0")
    conf:close()
end

--Modify conf of bird
function ModBird()
    local conf = io.open(Birdconf, "a")
    conf:write("protocol bgp ", OthersPeerInfo.Peername, " from BGP_peers {\n    neighbor ", OthersPeerInfo.IP, "%",
        OthersPeerInfo.Peername, " as ", OthersPeerInfo.ASN, ";\n}\n")
    conf:close()
end

--Modify conf of wg-quick-op
function ModWQO()
    --read conf to string
    local conf = io.open(WQOconf, "r")
    conf:seek("set", 0)
    local conftext = conf:read("*a")
    conf:close()

    --find "enabled:" and insert peername
    conftext = string.gsub(conftext, "enabled:", string.format("enabled:\n  - %s", OthersPeerInfo.Peername))
    --find "iface:" insert peername
    conftext = string.gsub(conftext, "iface:", string.format("iface:\n    - %s", OthersPeerInfo.Peername))

    --write it to file
    local conf = io.open(WQOconf, "w")
    conf:write(conftext)
    conf:close()
end

--Generate the log of port using
function GenPU()
    local conf = io.open(PUconf, "a")
    conf:write(YourPeerInfo.Port, "\t", OthersPeerInfo.Peername, "\n")
    conf:close()
end

--restart services
function ReSvc()
    os.execute("service bird restart")
    os.execute("service wg-quick-op restart")
end

--the main
---[[
print("Generating conf of wireguard...\n")
GenWg()
print("Modifying conf of bird...\n")
ModBird()
print("Modifying conf of wg-quick-op...\n")
ModWQO()
print("Generating log of port using...\nThe file is at ", PUconf, "\n")
GenPU()
print("Now restart services")
for i = 1, 3, 1 do
    ReSvc()
end
os.execute(string.format("wg-quick-op bounce %s", OthersPeerInfo.Peername))
os.execute(string.format("wg show %s", OthersPeerInfo.Peername))
os.execute("birdc s p")
--]]