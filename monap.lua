--[[
--	Description: a script for autopeer
--	Athor: Moncak
--]]

--TODO:加入文件指针判空
--算了其实出错的话lua自己会大声告诉你的

--load the peerinfo
dofile("src/info.lua")
dofile("src/functions.lua")

--generate and modify the confs
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

--aplly the confs
---[[
print("Now apply the confs\n")
os.execute(string.format("wg-quick-op up %s", OthersPeerInfo.Peername))
os.execute(string.format("wg-quick-op bounce %s", OthersPeerInfo.Peername))
os.execute("birdc c")
os.execute(string.format("wg show %s", OthersPeerInfo.Peername))
os.execute("birdc s p")
--]]