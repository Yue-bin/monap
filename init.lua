--[[
--	Description: a script for init your bird, wireguard and wg-quick-op
--	Athor: Moncak
--]]


--check
print("Noticing: this script will not check your infos, please check it youself before running\n")
print("Noticing: this script will clear the origin bird.conf and will not backup it\n")
print("Before using this script, please make sure you have installed bird, wireguard and wg-quick-op\nAnd you are using these things in this system for the first time\n")
print("If you are not sure, please press Ctrl+C to exit\nPress any key to continue\n")
io.read()

--load
dofile("src/info.lua")
dofile("src/functions.lua")

--init
print("Generating conf of bird...\n")
GenBird()
print("Generating directory of wireguard...\n")
os.execute("mkdir /etc/wireguard")
