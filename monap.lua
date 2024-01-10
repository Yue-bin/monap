--[[
--	Description: a script for autopeer
--	Athor: Moncak
--]]

--TODO:加入文件指针判空
--算了其实出错的话lua自己会大声告诉你的

--load the peerinfo
dofile("peerinfo.lua")

--Back up all the confs
function BackUp()
    if TestFile(Confs.WGconf) then
        os.execute(string.format("cp %s %s.bak", Confs.WGconf, Confs.WGconf))
    end
    if TestFile(Confs.Birdconf) then
        os.execute(string.format("cp %s %s.bak", Confs.Birdconf, Confs.Birdconf))
    end
    if TestFile(Confs.WQOconf) then
        os.execute(string.format("cp %s %s.bak", Confs.WQOconf, Confs.WQOconf))
    end
    if TestFile(Confs.PUconf) then
        os.execute(string.format("cp %s %s.bak", Confs.PUconf, Confs.PUconf))
    end
end

--Generate conf of wireguard
function GenWg()
    local conf = io.open(Confs.WGconf, "w")
    conf:write(
        "[Interface]\n",
        "PrivateKey = ", YourPeerInfo.PrivateKey, "\n",
        "ListenPort = ", YourPeerInfo.Port, "\n",
        "PostUp = /sbin/ip addr add dev %i ", YourPeerInfo.IP, "/32 peer ", OthersPeerInfo.IP, "/32\n",
        "Table = off\n",
        "MTU = 1420\n",
        "\n",
        "[Peer]\n")
    --if Endpoint is not empty, add it
    if OthersPeerInfo.Endpoint ~= "" then
        conf:write("Endpoint = ", OthersPeerInfo.Endpoint, "\n")
    end
    conf:write(
        "PublicKey = ", OthersPeerInfo.PublicKey, "\n",
        "AllowedIPs = 0.0.0.0/0")
    conf:close()
end

--Modify conf of bird
function ModBird()
    local conf = io.open(Confs.Birdconf, "a")
    conf:write("protocol bgp ", OthersPeerInfo.Peername, " from BGP_peers {\n    neighbor ", OthersPeerInfo.IP, "%",
        OthersPeerInfo.Peername, " as ", OthersPeerInfo.ASN, ";\n}\n")
    conf:close()
end

--Modify conf of wg-quick-op
function ModWQO()
    --read conf to string
    local conf = io.open(Confs.WQOconf, "r")
    conf:seek("set", 0)
    local conftext = conf:read("*a")
    conf:close()

    --find "enabled:" and insert peername
    conftext = string.gsub(conftext, "enabled:", string.format("enabled:\n  - %s", OthersPeerInfo.Peername))
    --find "iface:" insert peername
    conftext = string.gsub(conftext, "iface:", string.format("iface:\n    - %s", OthersPeerInfo.Peername))

    --write it to file
    local conf = io.open(Confs.WQOconf, "w")
    conf:write(conftext)
    conf:close()
end

--Generate the log of port using
function GenPU()
    local conf = io.open(Confs.PUconf, "a")
    conf:write(YourPeerInfo.Port, "\t", OthersPeerInfo.Peername, "\n")
    conf:close()
end

--the main
---[[
print("Back up all the confs...\n")
BackUp()
print("Generating conf of wireguard...\n")
GenWg()
print("Modifying conf of bird...\n")
ModBird()
print("Modifying conf of wg-quick-op...\n")
ModWQO()
print("Generating log of port using...\nThe file is at ", Confs.PUconf, "\n")
GenPU()
---[[
print("Now apply the confs\n")
os.execute(string.format("wg-quick-op up %s", OthersPeerInfo.Peername))
os.execute(string.format("wg-quick-op bounce %s", OthersPeerInfo.Peername))
os.execute("birdc c")
os.execute(string.format("wg show %s", OthersPeerInfo.Peername))
os.execute("birdc s p")
--]]