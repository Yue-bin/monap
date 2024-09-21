#!/usr/bin/env lua

-- monap
-- Description: a script for autopeer
-- Athor: Moncak

-- 版本号及名称
local version = "0.1.0"
local name = "monap"

local usage = [[
monap is a script for autopeer
Usage: ]] .. name .. [[ [COMMAND] [NAME] [OPTIONS]
    Commands:
        info: genarate the peerinfo
        peer: peer with others
        restore: restore the config file save by monap
        test: test the connection
        show: show the status of the connection
        showport: show the port in use
        install: install the monap and config file
        uninstall: remove the monap and (optional) config file
    NAME:
        the name of the peer
    Options:
        -v, --version: output version information and exit
        -h, --help: output this help information and exit
        -q, --quiet: quiet mode
        -c, --config <config-file>: specify the config file
        -i, --info <info-str>: the info string genarated by info command
        -s, --suffix <suffix>: specify the suffix of the backup file (default: bak)
        --prefix <prefix>: specify the prefix of the install path (default: /)
        --log-level <level>: specify the log level
            Loglevels: DEBUG INFO WARN ERROR FATAL
        -p, --port <port>: specify the port
        --no-bird: do not operate bird and config file of bird
        --no-wg: do not operate wireguard and config file of wireguard
        --old-wg-quick-op: use the config file wg-quick-op.yaml
]]

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
-- LOG_LEVEL = Loglevels.INFO
LOG_LEVEL = Loglevels.DEBUG

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
        else
            io.stderr:write("[" .. Loglevels[level] .. "]")
        end
    else
        -- 默认INFO
        io.stdout:write("[INFO]")
    end
    io.stdout:write(" " .. msg .. "\n")
    return true
end

-- 配置文件路径,monap会在seach_path..conf_path中搜索配置文件
local conf_path = "etc/monap/"
local seach_path = {
    "/",
    "/usr/",
    "/usr/local/",
    "./"
}
local ConfFile_name = "config.lua"

-- 输出帮助信息
local function print_usage()
    -- 参照ssh的usage输出使用了stderr)
    io.stderr:write(usage)
end

-- 输出版本信息
local function print_version()
    io.stderr:write(name .. " " .. version)
end

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

-- 处理参数：只要存在参数就返回true
local function find_option(arg_str, opt)
    if string.find(arg_str, opt, 1, true) then
        return true
    else
        return false
    end
end

-- 处理一般参数：参数和值都存在时才返回值，否则返回nil
local function find_option_with_value(arg_table, opt)
    for i = 1, #arg_table do
        if arg_table[i] == opt then
            if i + 1 <= #arg_table then
                return arg_table[i + 1]
            else
                return nil
            end
        end
    end
    return nil
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
                table.insert(portlist, { iname, port })
            end
        end
    end
    table.sort(portlist, function(a, b) return a[2] < b[2] end)
    return portlist
end

-- 解析info生成的peerinfo
local function parse_info(info)
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
    -- 检查是否有缺失的字段
    if not peerinfo.ASN or not peerinfo.IP or not peerinfo.PublicKey then
        return nil
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
    return peerinfo
end

-- 获取可用端口
local function get_port_available(portlist)
    local port = find_option_with_value(arg, "-p") or find_option_with_value(arg, "--port")
    if not port then
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
    return port
end

-- 生成peerinfo
local function do_info()
    if not YourPeerInfo then
        log("table \"YourPeerInfo\" not found in " .. ConfFile, Loglevels.ERROR)
        os.exit(126)
    end
    local portlist = gen_port_using()
    local port = get_port_available(portlist)
    io.stdout:write("Peerinfos:\n")
    io.stdout:write("\t" .. "ASN:" .. YourPeerInfo.ASN .. "\n")
    io.stdout:write("\t" .. "IP:" .. YourPeerInfo.IP .. "\n")
    io.stdout:write("\t" .. "Endpoint:" .. YourPeerInfo.Endpoint .. ":" .. port .. "\n")
    io.stdout:write("\t" .. "PublicKey:" .. YourPeerInfo.PublicKey .. "\n")
end

-- 与其他peer建立连接
local function do_peer()
    -- 读取info与预检查
    local infostr = find_option_with_value(arg, "-i") or find_option_with_value(arg, "--info")
    if not infostr then
        log("please specify the info string by -i or --info option", Loglevels.ERROR)
        os.exit(4)
    end
    local peerinfo = parse_info(infostr)
    if not peerinfo then
        log("invalid info string", Loglevels.ERROR)
        os.exit(5)
    end
    log("peer with " .. arg[2] .. " with info", Loglevels.INFO)
    log("ASN: " .. peerinfo.ASN, Loglevels.INFO)
    log("IP: " .. peerinfo.IP, Loglevels.INFO)
    log("Endpoint: " .. peerinfo.Endpoint, Loglevels.INFO)
    log("PublicKey: " .. peerinfo.PublicKey, Loglevels.INFO)
    io.stdout:write("if the peer info is correct, press any key to continue, or press Ctrl+C to exit\n")
    local _ = io.stdin:read()
    -- 生成wg配置文件
    if not find_option(argstr, "--no-wg") then
        log("generating wireguard config file", Loglevels.INFO)
        local conf_file = string.format(ConfPaths.WGconf_str, arg[2])
        local port = get_port_available(gen_port_using())
        if test_file(conf_file) then
            backup(conf_file)
        end
        local conf = io.open(conf_file, "w")
        if not conf then
            log("failed to open " .. conf_file, Loglevels.ERROR)
        else
            conf:write(GenWGConf(peerinfo, port))
            conf:close()
        end
        -- up这个接口
        log("up the wireguard interface", Loglevels.INFO)
        run_shell("wg-quick-op up " .. arg[2])
    end
    -- 修改wg-quick-op配置文件
    if find_option(argstr, "--old-wg-quick-op") or not OldWGOconf then
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
    if not find_option(argstr, "--no-bird") then
        log("modifying bird config file", Loglevels.INFO)
        local conf_file = ConfPaths.Birdconf
        if test_file(conf_file) then
            backup(conf_file)
        end
        local conf = io.open(conf_file, "a")
        if not conf then
            log("failed to open " .. conf_file, Loglevels.ERROR)
        else
            conf:write(GenBirdConf(arg[2], peerinfo))
            conf:close()
        end
        -- 测试配置文件
        --bird和birdc都没有-t选项，我有一些错误的记忆
        --log("testing bird config file", Loglevels.INFO)
        --run_shell("bird -t -c " .. conf_file)
        -- 重启bird
        log("reconfiguring bird", Loglevels.INFO)
        run_shell("birdc configure")
    end
    -- TODO:修改防火墙把接口添加到dn11区域
end

-- 恢复配置文件
local function do_restore()
    local suffix = find_option_with_value(arg, "-s") or find_option_with_value(arg, "--suffix") or "bak"
    io.stdout:write("Do you want to restore the bird config file? [y/N]: ")
    local answer = io.stdin:read()
    if answer == "y" then
        restore(ConfPaths.Birdconf, suffix)
    end
    io.stdout:write("\nDo you want to restore the wg-quick-op config file? [y/N]: ")
    answer = io.stdin:read()
    print(answer)
    if answer == "y" then
        restore(ConfPaths.WQOconf, suffix)
    end
    log("config file restored", Loglevels.INFO)
end

-- 测试连接
local function do_test()
    print("test")
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
    local prefix = find_option_with_value(arg, "-p") or find_option_with_value(arg, "--prefix") or "/"
    -- 安装bin
    run_shell("mkdir -p " .. prefix .. "bin")
    log("installing " .. name .. " to " .. prefix .. "bin/" .. name, Loglevels.INFO)
    run_shell("cp " .. arg[0] .. " " .. prefix .. "bin/" .. name)
    run_shell("chmod +x " .. prefix .. "bin/" .. name)
    -- 安装conf
    run_shell("mkdir -p " .. prefix .. conf_path)
    log("installing " .. ConfFile .. " to " .. prefix .. conf_path .. ConfFile_name, Loglevels.INFO)
    run_shell("cp " .. ConfFile .. " " .. prefix .. conf_path .. ConfFile_name)
end

-- 卸载monap
local function do_uninstall()
    -- 解析prefix
    local prefix = find_option_with_value(arg, "--prefix") or "/"
    -- 卸载bin
    log("removing " .. name .. " from " .. prefix .. "bin/" .. name, Loglevels.INFO)
    run_shell("rm " .. prefix .. "bin/" .. name)
    -- 卸载conf
    io.stdout:write("Do you want to remove the config file? [y/N]: ")
    local answer = io.stdin:read()
    if answer ~= "y" then
        os.exit(0)
    end
    log("removing " .. prefix .. conf_path .. ConfFile_name .. " from " .. prefix .. conf_path .. ConfFile_name,
        Loglevels.INFO)
    run_shell("rm " .. prefix .. conf_path .. ConfFile_name)
end


-- 解析命令行参数
-- 先处理输入为空的情况
if not ... then
    print_usage()
    os.exit(255)
end

-- 兼容性起见还是取一下(不知道5.1以后还有没有)
-- 我草你的这么搞没有arg[0]和负数索引了
--arg = { ... }

-- 把参数拼接成字符串方便查找全局参数
argstr = ""
for i = 1, #arg do
    argstr = argstr .. arg[i]
end

-- 处理-h选项
if find_option(argstr, "-h") or find_option(argstr, "--help") then
    print_usage()
    os.exit(0)
end

-- 再处理-v选项
if find_option(argstr, "-v") or find_option(argstr, "--version") then
    print_version()
    os.exit(0)
end

-- 处理-q选项
if find_option(argstr, "-q") or find_option(argstr, "--quiet") then
    NULL = io.open("/dev/null", "w")
    io.stdout = NULL
    io.stderr = NULL
end

-- 处理--log-level选项
LOG_LEVEL = find_option_with_value(arg, "--log-level") or LOG_LEVEL

-- 加载配置文件
-- 其实这里会有一个注入点存在，你可以直接往配置文件里狠狠注入
-- 但是一般情况下配置文件不会被奇奇怪怪的人摸到吧）
ConfFile = find_option_with_value(arg, "-c") or find_option_with_value(arg, "--config") or search_conf()
if not test_file(ConfFile) then
    io.stderr:write("config file not found\n")
    os.exit(2)
end
dofile(ConfFile)

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
else
    io.stderr:write("unknown command or option: " .. arg[1] .. "\n")
    print_usage()
    os.exit(22)
end
