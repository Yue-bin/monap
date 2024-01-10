--[[
--	Description: genarate the peerinfo that sent to others
--	Athor: Moncak
--]]


--load the peerinfo
dofile("src/info.lua")
dofile("src/functions.lua")

print("ASN:"..YourPeerInfo.ASN)
print("IP:"..YourPeerInfo.IP)
print("Endpoint:"..YourPeerInfo.Endpoint..":"..YourPeerInfo.Port)
print("PublicKey:"..YourPeerInfo.PublicKey)