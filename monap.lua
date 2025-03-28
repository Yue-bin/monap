#!/usr/bin/env lua

-- monap
-- Description: a script for autopeer
-- Athor: Moncak


--#region helper functions 和一些全局变量初始化
-- 版本号及名称
local version = "0.1.2"
local script_name = "monap"

local usage =
script_name .. [[ is a script for autopeer
Usage: ]] .. script_name .. [[ [COMMAND] [NAME] [OPTIONS]
    Commands:
        info: genarate the peerinfo
        peer: peer with others
        restore: restore the config file save by ]] .. script_name .. [[
        test: test the connection
        show: show the status of the connection
        showport: show the port in use
        install: install the ]] .. script_name .. [[ and config file
        uninstall: remove the ]] .. script_name .. [[ and (optional) config file
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
        --fw <firewall>: specify the firewall zone name (default: dn11/vpn)
        --no-fw: do not operate firewall
            will not affect the fwmark option
        --no-bird: do not operate bird and config file of bird
        --no-wg: do not operate wireguard and config file of wireguard
        --old-wg-quick-op: use the config file wg-quick-op.yaml
        --json: output peerinfo with json format
]]

-- 输出帮助信息
local function print_usage()
    -- 参照ssh的usage输出使用了stderr)
    io.stderr:write(usage)
end

-- 输出版本信息
local function print_version()
    io.stderr:write(script_name .. " " .. version)
end

-- 把所有标准流的输出改为立即刷新
io.stdout:setvbuf("no")
io.stderr:setvbuf("no")

-- 日志相关初始化
-- 搬了一点monlog,因为希望在单文件的情况下尽量减少依赖
Loglevels = {
    [0] = "DEBUG",
    [1] = "INFO",
    [2] = "WARN",
    [3] = "ERROR",
    [4] = "FATAL",
    DEBUG = 0,
    INFO = 1,
    WARN = 2,
    ERROR = 3,
    FATAL = 4
}
local loglevelmax = 4
local loglevelmin = 0
-- 默认日志级别
LOG_LEVEL = Loglevels.INFO
-- LOG_LEVEL = Loglevels.DEBUG

-- 输出日志到控制台
local function log(msg, level)
    if level ~= nil then
        assert((level >= loglevelmin and level <= loglevelmax), "level is invalid")
        if level < LOG_LEVEL then
            return false
        end
    end
    if level ~= nil then
        -- INFO及以上用stdout,其他用stderr
        if level <= Loglevels.INFO then
            io.stdout:write("[" .. Loglevels[level] .. "]")
            io.stdout:write(" " .. msg .. "\n")
        else
            io.stderr:write("[" .. Loglevels[level] .. "]")
            io.stderr:write(" " .. msg .. "\n")
        end
    else
        -- 默认INFO
        io.stdout:write("[INFO]")
        io.stdout:write(" " .. msg .. "\n")
    end
    return true
end


-- 配置文件相关初始化
-- 配置文件路径,monap会在seach_path..conf_path中搜索配置文件
local conf_path = "etc/monap/"
local seach_path = {
    "/",
    "/usr/",
    "/usr/local/",
    "./"
}
local ConfFile_name = "config.lua"


-- 较为基本的功能性的helper函数
-- 测试文件是否存在
local function test_file(file)
    local f = io.open(file, "r")
    if f ~= nil then
        f:close()
        return true
    else
        return false
    end
end

-- 运行shell并返回结果
local function run_shell(cmd)
    log("running shell: " .. cmd, Loglevels.DEBUG)
    local f = assert(io.popen(cmd, "r"))
    local s = assert(f:read("*a"))
    f:close()
    return s
end


-- 参数处理相关初始化
-- 把参数拼接成字符串方便查找参数
ArgString = ""
for i = 1, #arg do
    ArgString = ArgString .. arg[i]
end

-- 命令注册表
local cmd_reg = {
    ["info"] = "info",
    ["restore"] = "restore",
    ["showport"] = "showport",
    ["install"] = "install",
    ["uninstall"] = "uninstall"
}

-- 带值命令注册表
local cmd_val_reg = {
    ["peer"] = "peer",
    ["test"] = "test",
    ["show"] = "show"
}

-- flag参数注册表
local flag_reg = {
    ["-v"] = "version",
    ["--version"] = "version",
    ["-h"] = "help",
    ["--help"] = "help",
    ["-q"] = "quiet",
    ["--quiet"] = "quiet",
    ["--no-fw"] = "no-fw",
    ["--no-bird"] = "no-bird",
    ["--no-wg"] = "no-wg",
    ["--old-wg-quick-op"] = "old-wg-quick-op",
    ["--json"] = "json"
}

-- 带值参数注册表
local arg_reg = {
    ["-c"] = "config",
    ["--config"] = "config",
    ["-i"] = "info",
    ["--info"] = "info",
    ["--suffix"] = "suffix",
    ["--prefix"] = "prefix",
    ["--log-level"] = "log-level",
    ["-p"] = "port",
    ["--port"] = "port",
    ["--fwmark"] = "fwmark",
    ["--mtu"] = "mtu",
    ["--keepalive"] = "keepalive",
    ["--fw"] = "firewall"
}

-- 检查在哪个注册表中
local function find_reg(arg_str)
    if cmd_reg[arg_str] then
        return "cmd"
    elseif cmd_val_reg[arg_str] then
        return "cmd_val"
    elseif flag_reg[arg_str] then
        return "flag"
    elseif arg_reg[arg_str] then
        return "arg"
    else
        return nil
    end
end

-- 查找未注册的命令或选项,返回第一个未注册的参数和是否为带值参数的值
local function check_noreg()
    local i = 1
    while i <= #arg do
        local reg = find_reg(arg[i])
        if not reg then
            return arg[i], false
            -- 如果是带值参数就反向监测下一个参数,并跳过下一个参数
        elseif reg == "arg" or reg == "cmd_val" then
            if i + 1 > #arg or find_reg(arg[i + 1]) then
                return arg[i], true
            end
            i = i + 1
        end
        i = i + 1
    end
    return nil
end

-- 处理参数：只要存在参数就返回true
local function find_option(arg_name)
    -- 先查注册表找到对应的参数名
    for arg_str, arg_name_reg in pairs(flag_reg) do
        if arg_name == arg_name_reg then
            -- 再查实际的参数列表
            if string.find(ArgString, arg_str, 1, true) then
                return true
            end
        end
    end
    return false
end

-- 处理一般参数：参数和值都存在时才返回值，否则返回nil
local function find_option_with_value(arg_name)
    for arg_str, arg_name_reg in pairs(arg_reg) do
        if arg_name == arg_name_reg then
            for i = 1, #arg do
                if arg[i] == arg_str then
                    if i + 1 <= #arg then
                        return arg[i + 1]
                    else
                        return nil
                    end
                end
            end
        end
    end
    return nil
end


-- 搜索配置文件
local function search_conf()
    local path = ""
    local flag = false
    for i = 1, #seach_path do
        path = seach_path[i] .. conf_path .. ConfFile_name
        -- 事实上因为配置文件未加载，所以这里的log不会输出
        -- 但是无所谓因为这里的log只是为了调试
        log("searching: " .. path, Loglevels.DEBUG)
        if test_file(path) then
            flag = true
            log("config file found: " .. path, Loglevels.INFO)
            break
        end
    end
    if not flag then
        io.stderr:write("config file not found\n")
        os.exit(2)
    end
    return path
end


-- 一些不那么基础的功能性的helper函数
-- 备份配置文件,不指定后缀则默认为bak
local function backup(conf, suffix)
    if type(suffix) ~= "nil" and type(suffix) ~= "string" then
        log("suffix must be a string", Loglevels.ERROR)
        os.exit(8)
    end
    if test_file(conf) then
        log("file not found", Loglevels.ERROR)
    end
    if suffix == nil then
        suffix = "bak"
    end
    if test_file(conf .. suffix) then
        io.stdout:write("backup file already exists, do you want to overwrite it? [y/N]: ")
        local answer = io.stdin:read()
        if answer ~= "y" then
            return
        end
    end
    os.execute(string.format("cp %s %s." .. suffix, conf, conf))
end

-- 恢复配置文件
local function restore(conf, suffix)
    if type(suffix) ~= "nil" and type(suffix) ~= "string" then
        log("suffix must be a string", Loglevels.ERROR)
        os.exit(8)
    end
    if test_file(conf .. "." .. suffix) then
        log("backup file not found", Loglevels.ERROR)
    end
    os.execute(string.format("cp %s.%s %s", conf, suffix, conf))
end

-- 从wg配置文件中获取port
local function get_port_from_wgconf(conf)
    local f = assert(io.open(conf, "r"))
    if not f then
        return nil
    end
    local port = nil
    for line in f:lines() do
        port = line:match("ListenPort%s*=%s*(%d+)")
        if port then
            break
        end
    end
    f:close()
    return port
end

-- 生成正在使用的端口列表
local function gen_port_using()
    local filelist = run_shell("ls " .. string.format(ConfPaths.WGconf_str, "*"))
    local portlist = {}
    if filelist then
        for filename in filelist:gmatch("[^\r\n]+") do
            local iname = filename:match(string.format(ConfPaths.WGconf_str, "(.*)"))
            local port = get_port_from_wgconf(filename)
            if port then
                port = tonumber(port)
                if port >= PortRange.Min and port <= PortRange.Max then
                    table.insert(portlist, { iname, port })
                else
                    log("port " .. port .. " from file " .. filename .. " is out of range, ignore it", Loglevels.INFO)
                end
            end
        end
    end
    table.sort(portlist, function(a, b) return a[2] < b[2] end)
    return portlist
end

-- 解析plain text格式的peerinfo
local function parse_info_in_plain(info)
    local peerinfo = {}
    for line in info:gmatch("[^\r\n]+") do
        -- 跳过包含 'Peerinfos:' 的行
        if not line:find("Peerinfos:") then
            local key, value = line:match("(%a+):(.+)")
            if key and value then
                peerinfo[key] = value
            end
        end
    end
    return peerinfo
end

-- 解析json格式的peerinfo
local function parse_info_in_json(info)
    local status, json = pcall(require, "luci.jsonc")
    if not status then
        log("failed to require luci.jsonc...", Loglevels.ERROR)
        log("errmsg: " .. json, Loglevels.DEBUG)
        return nil
    end
    local peerinfo, err = json.parse(info)
    if not peerinfo then
        log("failed to parse json string", Loglevels.WARN)
        log("errmsg: " .. err, Loglevels.DEBUG)
        return nil
    end
    return peerinfo
end

local function check_peerinfo(peerinfo)
    -- 检查是否有缺失的必要字段
    if not peerinfo.ASN or not peerinfo.IP or not peerinfo.PublicKey then
        return false
    end
    -- 检查字段常规合法性
    -- ASN
    -- dn11的ASN长度一般是10
    if #peerinfo.ASN ~= 10 then
        log("ASN length is not 10 , but " .. #peerinfo.ASN, Loglevels.WARN)
    end
    if peerinfo.ASN:match("[^%d]") then
        log("ASN contains non-digit character", Loglevels.WARN)
    end
    -- IP
    if not peerinfo.IP:match("^%d+%.%d+%.%d+%.%d+$") then
        log("invalid IP in IPv4", Loglevels.WARN)
    end
    -- Endpoint
    if not peerinfo.Endpoint:match("^[%a%d%-%.]+:%d+$") then
        log("not a common Endpoint", Loglevels.WARN)
    end
    -- PublicKey
    if #peerinfo.PublicKey ~= 44 then
        log("PublicKey length is not 44 , but " .. #peerinfo.PublicKey, Loglevels.WARN)
    end
    return true
end

-- 解析info生成的peerinfo
local function parse_info(info)
    local peerinfo = parse_info_in_json(info) or parse_info_in_plain(info)
    if check_peerinfo(peerinfo) then
        return peerinfo
    end
    return nil
end

-- 获取可用端口
local function get_port_available()
    local port = find_option_with_value("port")
    if not port then
        local portlist = gen_port_using()
        if not portlist or #portlist < 1 then
            log("no port in use, please specify the port", Loglevels.ERROR)
            os.exit(6)
        end
        if #portlist > 0 then
            if PortGenMethod == "+" then
                port = portlist[#portlist][2] + 1
            elseif PortGenMethod == "-" then
                port = portlist[1][2] - 1
            else
                log("invalid PortGenMethod", Loglevels.ERROR)
                os.exit(3)
            end
        end
    end
    port = tonumber(port)
    if port < PortRange.Min or port > PortRange.Max then
        log("port " .. port .. " is out of setted range", Loglevels.WARN)
    end
    return port
end

-- 生成wireguard配置文件
local function gen_wg_conf(peerinfo, port, fwmark, mtu, keepalive)
    -- 从模板进行那个超级大替换啊
    -- 先处理必选项
    local conf = string.gsub(WGConfT, "<pri_key>", YourPeerInfo.PrivateKey)
    conf = string.gsub(conf, "<port>", port)
    conf = string.gsub(conf, "<local_ip>", YourPeerInfo.IP)
    conf = string.gsub(conf, "<peer_ip>", peerinfo.IP)
    conf = string.gsub(conf, "<mtu>", mtu or "1388")
    conf = string.gsub(conf, "<pub_key>", peerinfo.PublicKey)
    -- 然后处理可选项,替换并取消注释
    if fwmark then
        -- 我草了copylot这个匹配替换的思路简直是天才
        -- 就是他可能不太知道我匹配的具体情况还得改
        conf = string.gsub(conf, "#%s*([^\n\r]-fwmark.-[\n\r])", "%1")
        conf = string.gsub(conf, "<fwmark>", fwmark)
    end
    if peerinfo.Endpoint ~= "" then
        conf = string.gsub(conf, "#%s*([^\n\r]-endpoint.-[\n\r])", "%1")
        conf = string.gsub(conf, "<endpoint>", peerinfo.Endpoint)
    end
    if keepalive then
        conf = string.gsub(conf, "#%s*([^\n\r]-keepalive.-[\n\r])", "%1")
        conf = string.gsub(conf, "<keepalive>", keepalive)
    end
    return conf
end

-- 生成bird配置文件
local function gen_bird_conf(peername, peerinfo)
    local conf = string.gsub(BirdConfT, "<name>", peername)
    conf = string.gsub(conf, "<peer_ip>", peerinfo.IP)
    conf = string.gsub(conf, "<asn>", peerinfo.ASN)
    return conf
end
--#endregion


--#region main functions
-- 生成peerinfo
local function do_info()
    if not YourPeerInfo then
        log("table \"YourPeerInfo\" not found in " .. ConfFile, Loglevels.ERROR)
        os.exit(126)
    end
    local port = get_port_available()
    local peerinfo = {
        ASN = YourPeerInfo.ASN,
        IP = YourPeerInfo.IP,
        Endpoint = YourPeerInfo.Endpoint .. ":" .. port,
        PublicKey = YourPeerInfo.PublicKey
    }
    if find_option("json") then
        local status, json = pcall(require, "luci.jsonc")
        if not status then
            log("failed to require luci.jsonc...", Loglevels.ERROR)
            log("errmsg: " .. json, Loglevels.DEBUG)
        else
            --io.stdout:write("Peerinfos:\n")
            if PrettyJson == nil then
                io.stdout:write(json.stringify(peerinfo, true) .. "\n")
            else
                local PrettyJson = PrettyJson or false
                log("PrettyJson is enabled: " .. tostring(PrettyJson), Loglevels.DEBUG)
                io.stdout:write(json.stringify(peerinfo, PrettyJson) .. "\n")
            end
        end
    else
        io.stdout:write("Peerinfos:\n")
        for k, v in pairs(peerinfo) do
            io.stdout:write("\t" .. k .. ": " .. v .. "\n")
        end
    end
end


-- 如果检查失败要用到恢复，先声明一下
local do_restore
-- 与其他peer建立连接
local function do_peer()
    -- 读取info与预检查
    local infostr = find_option_with_value("info")
    if not infostr then
        log("please specify the info string by -i or --info option", Loglevels.ERROR)
        os.exit(4)
    end
    local peerinfo = parse_info(infostr)
    if not peerinfo then
        log("invalid info string", Loglevels.ERROR)
        os.exit(5)
    end
    local port = get_port_available()
    local fwmark = find_option_with_value("fwmark")
    local mtu = find_option_with_value("mtu")
    local keepalive = find_option_with_value("keepalive")
    log("peer with " .. arg[2] .. " with info", Loglevels.INFO)
    log("ASN: " .. peerinfo.ASN, Loglevels.INFO)
    log("IP: " .. peerinfo.IP, Loglevels.INFO)
    log("Endpoint: " .. peerinfo.Endpoint, Loglevels.INFO)
    log("PublicKey: " .. peerinfo.PublicKey, Loglevels.INFO)
    log("ListenPort: " .. port, Loglevels.INFO)
    if fwmark then
        log("Fwmark: " .. fwmark, Loglevels.INFO)
    end
    if mtu then
        log("MTU: " .. mtu, Loglevels.INFO)
    end
    if keepalive then
        log("Keepalive: " .. keepalive, Loglevels.INFO)
    end
    io.stdout:write("if the peer info is correct, press any key to continue, or press Ctrl+C to exit\n")
    local _ = io.stdin:read()
    -- 生成wg配置文件
    if not find_option("no-wg") then
        log("generating wireguard config file", Loglevels.INFO)
        local conf_file = string.format(ConfPaths.WGconf_str, arg[2])
        if test_file(conf_file) then
            backup(conf_file)
        end
        local conf = io.open(conf_file, "w")
        if not conf then
            log("failed to open " .. conf_file, Loglevels.ERROR)
        else
            conf:write(gen_wg_conf(peerinfo, port, fwmark, mtu, keepalive))
            conf:close()
        end
        -- up这个接口
        log("up the wireguard interface", Loglevels.INFO)
        run_shell("wg-quick-op up " .. arg[2])
    end
    -- 修改防火墙
    if not find_option("no-fw") then
        log("operating firewall", Loglevels.INFO)
        local fw_zone_name = find_option_with_value("firewall")
        -- mainly from https://github.com/dn-11/luci-network-dn11
        local status, uci = pcall(require, "luci.model.uci")
        if not status then
            log("failed to require uci... skip the firewall operate", Loglevels.ERROR)
            log("errmsg: " .. uci, Loglevels.DEBUG)
        else
            uci = uci.cursor()
            local zones = uci:get_all("firewall")
            local vpn_zone
            for name, zone in pairs(zones) do
                log("checking firewall zone " .. name, Loglevels.DEBUG)
                if zone.name == fw_zone_name then
                    vpn_zone = name
                    break
                elseif zone.name == 'dn11' then
                    vpn_zone = name
                    break
                elseif zone.name == 'vpn' then
                    vpn_zone = name
                    break
                end
            end
            if vpn_zone then
                log("adding interface " .. arg[2] .. " to firewall zone" .. vpn_zone, Loglevels.INFO)
                local device_list = uci:get("firewall", vpn_zone, "device") or {}
                table.insert(device_list, arg[2])
                uci:set_list("firewall", vpn_zone, "device", device_list)
                uci:commit("firewall")
                run_shell("/etc/init.d/firewall reload")
            end
        end
    end
    -- 修改wg-quick-op配置文件
    if OldWGOconf then
        log("modifying wg-quick-op config file", Loglevels.INFO)
        local conf_file = ConfPaths.WQOconf
        if test_file(conf_file) then
            backup(conf_file)
        end
        -- 这一段直接从旧版抄的，由于新版中已经失去了这个功能，所以我也不打算维护了
        --read conf to string
        local conf = io.open(ConfPaths.WQOconf, "r")

        if not conf then
            log("failed to open " .. conf_file, Loglevels.ERROR)
        else
            conf:seek("set", 0)
            local conftext = conf:read("*a")
            conf:close()

            --find "enabled:" and insert peername
            conftext = string.gsub(conftext, "enabled:", string.format("enabled:\n  - %s", arg[2]))
            --find "iface:" insert peername
            conftext = string.gsub(conftext, "iface:", string.format("iface:\n    - %s", arg[2]))

            --write it to file
            local conf = io.open(ConfPaths.WQOconf, "w")
            if not conf then
                log("failed to open " .. conf_file, Loglevels.ERROR)
            else
                conf:write(conftext)
                conf:close()
            end
        end
        -- 重启wg-quick-op
        log("restarting wg-quick-op", Loglevels.INFO)
        run_shell("service wg-quick-op restart")
    end
    -- 修改bird配置文件
    if not find_option("no-bird") then
        log("modifying bird config file", Loglevels.INFO)
        local conf_file = ConfPaths.Birdconf
        if test_file(conf_file) then
            backup(conf_file)
        end
        local conf = io.open(conf_file, "a")
        if not conf then
            log("failed to open " .. conf_file, Loglevels.ERROR)
        else
            conf:write(gen_bird_conf(arg[2], peerinfo))
            conf:close()
        end
        -- 测试配置文件
        --bird和birdc都没有-t选项，我有一些错误的记忆
        --log("testing bird config file", Loglevels.INFO)
        --run_shell("bird -t -c " .. conf_file)
        log("testing bird config file", Loglevels.INFO)
        local result = run_shell("birdc configure check")
        if string.match(result, "Configuration OK") then
            -- 重启bird
            log("reconfiguring bird", Loglevels.INFO)
            run_shell("birdc configure")
        else
            log("bird config file is invalid, here's output of bird", Loglevels.ERROR)
            io.stderr:write(result)
            log("enter the restore mode", Loglevels.INFO)
            do_restore()
        end
    end
end

-- 恢复配置文件
function do_restore()
    local suffix = find_option_with_value("suffix") or "bak"
    io.stdout:write("Do you want to restore the bird config file? [y/N]: ")
    local answer = io.stdin:read()
    if answer == "y" then
        restore(ConfPaths.Birdconf, suffix)
    end
    if not OldWGOconf then
        log("new version of wg-quick-op does not need backup restore", Loglevels.INFO)
    end
    io.stdout:write("Do you want to restore the wg-quick-op config file? [y/N]: ")
    answer = io.stdin:read()
    print(answer)
    if answer == "y" then
        restore(ConfPaths.WQOconf, suffix)
    end
    log("config file restored", Loglevels.INFO)
end

-- 测试连接
local function do_test()
    log("this function has not been implemented yet", Loglevels.ERROR)
end

-- 显示连接状态
local function do_show()
    io.stdout:write("this function assume that all the interfaces is named " .. arg[2] .. "\n")
    io.stdout:write(run_shell("wg show " .. arg[2]) .. "\n")
    io.stdout:write(run_shell("birdc show protocol " .. arg[2]) .. "\n")
end

-- 显示端口使用情况
local function do_showport()
    local portlist = gen_port_using()
    for _, v in pairs(portlist) do
        print(v[1], v[2])
    end
end

-- 安装monap
local function do_install()
    -- 解析prefix
    local prefix = find_option_with_value("prefix") or "/"
    -- 安装bin
    local bin_path = prefix .. "usr/bin/" .. script_name
    run_shell("mkdir -p " .. prefix .. "usr/bin")
    log("installing " .. script_name .. " to " .. bin_path, Loglevels.INFO)
    run_shell("cp -f " .. arg[0] .. " " .. bin_path)
    run_shell("chmod +x " .. bin_path)
    -- 安装conf
    local conf_path_install = prefix .. conf_path .. ConfFile_name
    if test_file(conf_path_install) then
        log("config file already exists", Loglevels.ERROR)
        log("please check " .. conf_path_install .. " and the " .. ConfFile .. " and update it yourself", Loglevels
            .ERROR)
    else
        run_shell("mkdir -p " .. prefix .. conf_path)
        log("installing " .. ConfFile .. " to " .. conf_path_install, Loglevels.INFO)
        run_shell("cp " .. ConfFile .. " " .. conf_path_install)
    end
end

-- 卸载monap
local function do_uninstall()
    -- 解析prefix
    local prefix = find_option_with_value("prefix") or "/"
    io.stdout:write("Do you want to remove the config file? [y/N]: ")
    io.stdout:flush()
    local answer = io.stdin:read()
    if answer == "y" then
        -- 卸载conf
        local conf_path_install = prefix .. conf_path .. ConfFile_name
        log("removing " .. ConfFile_name .. " from " .. conf_path_install, Loglevels.INFO)
        run_shell("rm " .. conf_path_install)
    end
    -- 我草你的Op的busybox不能自己删自己
    --run_shell("rm " .. bin_path)
    -- 卸载bin
    local bin_path = prefix .. "usr/bin/" .. script_name
    log("removing " .. script_name .. " from " .. bin_path, Loglevels.INFO)
    os.execute("rm " .. bin_path)
end
--#endregion



--#region main process
-- 解析命令行参数
-- 先处理输入为空的情况
if not ... then
    print_usage()
    os.exit(255)
end

-- 兼容性起见还是取一下(不知道5.1以后还有没有)
-- 我草你的这么搞没有arg[0]和负数索引了
--arg = { ... }

-- 处理help选项
if find_option("help") then
    print_usage()
    os.exit(0)
end

-- 查找不存在于注册表中的命令或选项
local noreg, with_value = check_noreg()
if noreg then
    if with_value then
        io.stderr:write("missing value for arguement: " .. noreg .. "\n")
        print_usage()
        os.exit(22)
    end
    io.stderr:write("unknown command or option: " .. noreg .. "\n")
    print_usage()
    os.exit(22)
end

-- 再处理version选项
if find_option("version") then
    print_version()
    os.exit(0)
end

-- 处理quiet选项
if find_option("quiet") then
    NULL = io.open("/dev/null", "w")
    io.stdout = NULL
    io.stderr = NULL
end

-- 处理--log-level选项
LOG_LEVEL = Loglevels[find_option_with_value("log-level")] or LOG_LEVEL

-- 加载配置文件
-- 其实这里会有一个注入点存在，你可以直接往配置文件里狠狠注入
-- 但是一般情况下配置文件不会被奇奇怪怪的人摸到吧）
ConfFile = find_option_with_value("config") or search_conf()
if not test_file(ConfFile) then
    io.stderr:write("config file not found\n")
    os.exit(2)
end
dofile(ConfFile)
-- 处理一下默认值
PortRange = PortRange or {}
PortRange.Min = PortRange.Min or 0
PortRange.Max = PortRange.Max or 65535

-- 因为手动指定的log-level应凌驾于配置文件中的log-level之上，所以再处理一次
-- 处理--log-level选项
LOG_LEVEL = Loglevels[find_option_with_value("log-level")] or LOG_LEVEL

-- 处理出现在config中的flag
OldWGOconf = find_option("old-wg-quick-op") or OldWGOconf

-- 再处理正常的COMMANDS,OPTIONS放到具体的函数中处理
--[[
Commands:
        info: genarate the peerinfo
        peer: peer with others
        restore: restore the config file save by monap
        test: test the connection
        show: show the status of the connection
        showport: show the port in use
        install: install the monap and config file
        uninstall: remove the monap and (optional) config file
]]
--print(arg[1])
if arg[1] == "info" then
    do_info()
elseif arg[1] == "peer" then
    do_peer()
elseif arg[1] == "restore" then
    do_restore()
elseif arg[1] == "test" then
    do_test()
elseif arg[1] == "show" then
    do_show()
elseif arg[1] == "showport" then
    do_showport()
elseif arg[1] == "install" then
    do_install()
elseif arg[1] == "uninstall" then
    do_uninstall()
end
os.exit(0)
--#endregion
