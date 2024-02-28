--[[
--	Description: helper functions for monap
--	Athor: Moncak
--]]


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


--Restore all the confs
function Restore()
    if TestFile(Confs.WGconf..".bak") then
        print("The backup of wireguard conf is exists, restore it...\n")
        os.execute(string.format("mv %s.bak %s", Confs.WGconf, Confs.WGconf))
    else
        if TestFile(Confs.WGconf) then
            print("The conf of wireguard is exists and the backup is not exists, remove it...\n")
            os.execute(string.format("rm %s", Confs.WGconf))
        else
            print("The conf of wireguard is not exists, skip it...\n")
        end
    end
    if TestFile(Confs.Birdconf..".bak") then
        os.execute(string.format("mv %s.bak %s", Confs.Birdconf, Confs.Birdconf))
    else
        print("The backup of bird conf is not exists, skip it...\n")
    end
    if TestFile(Confs.WQOconf..".bak") then
        os.execute(string.format("mv %s.bak %s", Confs.WQOconf, Confs.WQOconf))
    else
        print("The backup of wg-quick-op conf is not exists, skip it...\n")
    end
    if TestFile(Confs.PUconf..".bak") then
        os.execute(string.format("mv %s.bak %s", Confs.PUconf, Confs.PUconf))
    else
        print("The backup of port_using log is not exists, skip it...\n")
    end
end


--Genarate the bird.conf
function GenBird()
    --clear the origin conf
    os.execute("echo > "..Confs.Birdconf)
    --write the conf
    ---[[
    local conf = io.open(Confs.Birdconf, "w")
    --全抄的dn11 wiki
    conf:write(
        "log syslog all;\n",
        "debug protocols all;\n\n",
        "# 可以采用隧道地址，也可以采用路由所在的IP，在自己的网段内且不重复即可\n",
        "router id ", YourPeerInfo.IP, ";\n\n",
        "# 分表，给后期的其他配置留一点回旋的余地\n",
        "ipv4 table BGP_table;\n\n",
        "protocol device{\n\n",
        "}\n\n",
        "# 从 master4 导出所有路由表到 kernel\n",
        "protocol kernel{\n",
        "    ipv4 {\n",
        "        export all;\n",
        "        import none;\n",
        "    };\n",
        "}\n\n",
        "# 宣告 ", YourPeerInfo.IPSegment, " 段\n",
        "protocol static {\n",
        "    ipv4 {\n",
        "        table BGP_table;\n",
        "        import all;\n",
        "        export none;\n",
        "    };\n\n",
        "    # 只是为了让BGP的路由表里出现这条路由，不要担心 reject\n",
        "    # 这个动作其实无所谓，reject 这个动作并不会被发到其他 AS\n",
        "    # 后续将在导出到 master4 的时候删除这条路由，本地也不会有这一条\n",
        "    # 请修改为你自己要宣告的段\n",
        "    route ", YourPeerInfo.IPSegment, " reject;\n",
        "}\n\n",
        "# 定义BGP模板\n",
        "template bgp BGP_peers {\n",
        "    # 修改为隧道地址和你的ASN \n",
        "    local ", YourPeerInfo.IP, " as ", YourPeerInfo.ASN, ";\n\n",
        "    ipv4 {\n",
        "        table BGP_table;\n",
        "        import all;\n",
        "        export filter {\n",
        "            if source ~ [RTS_STATIC, RTS_BGP] then accept;\n",
        "            reject;\n",
        "        };\n",
        "    };\n",
        "}\n\n",
        "protocol bgp collect_self {\n",
        "    local as ", YourPeerInfo.ASN, ";\n",
        "    neighbor 172.16.255.1 as 4211110101;\n",
        "    multihop;\n",
        "    ipv4 {\n",
        "        add paths tx;\n",
        "        # 修改为你的 BGP Table\n",
        "        table BGP_table;\n",
        "        import none;\n",
        "        # 如果你使用 protocol static 宣告网段无需修改\n",
        "        # 如果你使用重分发，自行修改过滤规则\n",
        "        export filter {\n",
        "            if source ~ [RTS_BGP,RTS_STATIC] then accept;\n",
        "            reject;\n",
        "        };\n",
        "    };\n",
        "}\n\n",
        "# 从 BGP_table 导入路由到 master4\n",
        "protocol pipe {\n",
        "    table master4;\n",
        "    peer table BGP_table;\n",
        "    import filter {\n",
        "        # 过滤 protocol static 添加的 reject\n",
        "        if source = RTS_STATIC then reject;\n",
        "        accept;\n",
        "    };\n",
        "    export none;\n",
        "}\n\n",
        "# 从模板定义一个BGP邻居\n",
        "# protocol bgp protocol名称 from 模板名称\n",
        "# protocol bgp hakuya from BGP_peers {\n",
        "    # 对端隧道地址%接口 as ASN\n",
        "    # neighbor 172.16.0.254%hakuya as 4220081919;\n",
        "# }\n" 
    )
    conf:close()
    --]]
end
