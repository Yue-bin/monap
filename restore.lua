--[[
--	Description: restore the confs
--	Athor: Moncak
--]]

--load the peerinfo
dofile("peerinfo.lua")

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

--Restore
Restore()