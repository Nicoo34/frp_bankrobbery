local Tunnel = module("_core", "lib/Tunnel")
local Proxy = module("_core", "lib/Proxy")

API = Proxy.getInterface("API")
cAPI = Tunnel.getInterface("API")

RegisterServerEvent('FRP:TITLESWASH:washMoney')
AddEventHandler('FRP:TITLESWASH:washMoney', function()
    local _source = source
    local User = API.getUserFromSource(source)
    local Character = User:getCharacter()
	local Inventory = Character:getInventory()

	local accountMoney = 0
	local bankbag = 0
	
	accountMoney = Inventory:getItemAmount("titles")
	bankbag = Inventory:getItemAmount("moneybag")

	rewardbank = math.random(200, 800)

	if bankbag < 1 then
		User:notify("error", "You have nothing to trade.")
	else
		Inventory:addItem("money", rewardbank)
		Inventory:removeItem(-1, "moneybag", 1)
		User:notify("item", "money", rewardbank)
	end 

	if accountMoney < 99 then
		User:notify("error", "You have nothing to trade.")
	else
		Inventory:addItem("money", 50)
		Inventory:removeItem(-1, "titles", 1)
		User:notify("item", "money", 50/100)
	end
end)