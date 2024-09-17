#!/usr/bin/env lua

-- monap
-- Description: a script for autopeer
-- Athor: Moncak

-- 版本号及名称
local version = "0.1.0"
local name = "monap"

local usage = [[
monap is a script for autopeer
Usage: monap [COMMAND] [OPTIONS]
    Commands:
        init: init the config file
        info: genarate the peerinfo
        peer: peer with others
    Options:
        -v, --version: output version information and exit
        -h, --help: output this help information and exit
        -c, --config <config-file>: specify the config file
        -i, --info <info-file>: specify the info file
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
        assert((level >= loglevelmin and level <= loglevelmax), "level is valid")
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
local ConfFile_name = "info.lua"

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

-- 初始化
local function do_init()
    print("init")
end

-- 生成peerinfo
local function do_info()
    if not YourPeerInfo then
        log("table \"YourPeerInfo\" not found in " .. ConfFile, Loglevels.ERROR)
        os.exit(126)
    end
    io.stdout:write("Peerinfos:\n")
    io.stdout:write("\t" .. "ASN:" .. YourPeerInfo.ASN .. "\n")
    io.stdout:write("\t" .. "IP:" .. YourPeerInfo.IP .. "\n")
    io.stdout:write("\t" .. "Endpoint:" .. YourPeerInfo.Endpoint .. ":" .. YourPeerInfo.Port .. "\n")
    io.stdout:write("\t" .. "PublicKey:" .. YourPeerInfo.PublicKey .. "\n")
end

-- 与其他peer建立连接
local function do_peer()
    print("peer")
end

-- 解析命令行参数
-- 先处理-h选项和输入为空的情况
if not ... or string.find(..., "-h", 1, true) or string.find(..., "--help", 1, true) then
    print_usage()
    os.exit(255)
end

-- 再处理-v选项
if string.find(..., "-v", 1, true) or string.find(..., "--version", 1, true) then
    print_version()
    os.exit(0)
end

-- 加载配置文件
ConfFile = search_conf()
dofile(ConfFile)

-- 再处理正常的COMMANDS,OPTIONS放到具体的函数中处理
if arg[1] == "init" then
    do_init()
elseif arg[1] == "info" then
    do_info()
elseif arg[1] == "peer" then
    do_peer()
else
    io.stderr:write("unknown command or option: " .. arg[1] .. "\n")
    print_usage()
    os.exit(22)
end
