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
        install: install the monap and config file
        uninstall: remove the monap and (optional) config file
    NAME:
        the name of the peer
    Options:
        -v, --version: output version information and exit
        -h, --help: output this help information and exit
        -q, --quiet: quiet mode
        -c, --config <config-file>: specify the config file
        -i, --info <info-file>: specify the info file
        -s, --suffix <suffix>: specify the suffix of the backup file (default: bak)
        --prefix <prefix>: specify the prefix of the install path (default: /)
        --log-level <level>: specify the log level
            Loglevels: DEBUG INFO WARN ERROR FATAL
        -p, --port <port>: specify the port
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
    assert(type(suffix) == "nil" or type(suffix) == "string", "suffix must be a string")
    assert(test_file(conf), "file not found")
    if suffix == nil then
        suffix = "bak"
    end
    os.execute(string.format("cp %s %s." .. suffix, conf, conf))
end

-- 处理全局类型的参数：只要存在参数就返回true
local function find_global_option(argstr, opt)
    if string.find(argstr, opt, 1, true) then
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
        port = line:match("ListenPort = (%d+)")
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

-- 生成peerinfo
local function do_info()
    if not YourPeerInfo then
        log("table \"YourPeerInfo\" not found in " .. ConfFile, Loglevels.ERROR)
        os.exit(126)
    end
    local portlist = gen_port_using()
    local port = find_option_with_value(arg, "-p") or find_option_with_value(arg, "--port")
    if not port then
        if portlist == {} then
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
    io.stdout:write("Peerinfos:\n")
    io.stdout:write("\t" .. "ASN:" .. YourPeerInfo.ASN .. "\n")
    io.stdout:write("\t" .. "IP:" .. YourPeerInfo.IP .. "\n")
    io.stdout:write("\t" .. "Endpoint:" .. YourPeerInfo.Endpoint .. ":" .. port .. "\n")
    io.stdout:write("\t" .. "PublicKey:" .. YourPeerInfo.PublicKey .. "\n")
end

-- 与其他peer建立连接
local function do_peer()
    print("peer")
end

-- 恢复配置文件
local function do_restore()
    print("restore")
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
local argstr = ""
for i = 1, #arg do
    argstr = argstr .. arg[i]
end

-- 处理-h选项
if find_global_option(argstr, "-h") or find_global_option(argstr, "--help") then
    print_usage()
    os.exit(0)
end

-- 再处理-v选项
if find_global_option(argstr, "-v") or find_global_option(argstr, "--version") then
    print_version()
    os.exit(0)
end

-- 处理-q选项
if find_global_option(argstr, "-q") or find_global_option(argstr, "--quiet") then
    NULL = io.open("/dev/null", "w")
    io.stdout = NULL
    io.stderr = NULL
end

-- 加载配置文件
-- 其实这里会有一个注入点存在，你可以直接往配置文件里狠狠注入
-- 但是一般情况下配置文件不会被奇奇怪怪的人摸到吧）
ConfFile = search_conf()
dofile(ConfFile)

-- 再处理正常的COMMANDS,OPTIONS放到具体的函数中处理
--[[
Commands:
        info: genarate the peerinfo
        peer: peer with others
        restore: restore the config file save by monap
        test: test the connection
        show: show the status of the connection
        install: install the monap and config file
        uninstall: remove the monap and (optional) config file
]]
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
elseif arg[1] == "install" then
    do_install()
elseif arg[1] == "uninstall" then
    do_uninstall()
else
    io.stderr:write("unknown command or option: " .. arg[1] .. "\n")
    print_usage()
    os.exit(22)
end
