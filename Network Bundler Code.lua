local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local isServer = RunService:IsServer()
local NetworkBundle = {}

NetworkBundle.__index = NetworkBundle

local function Setup(...)
	
	if isServer then
		
		local Folder = Instance.new("Folder")
		
		Folder.Name = "NetworkBundles"
		Folder.Parent = ReplicatedStorage
		
		return Folder	
		
	else
		
		return ReplicatedStorage:FindFirstChild("NetworkBundles") or ReplicatedStorage:WaitForChild("NetworkBundles", ...)
		
	end
end

local function createEvent(name)
	
	local Event = Instance.new("RemoteEvent")
	
	Event.Name = name
	Event.Parent = ReplicatedStorage:FindFirstChild("NetworkBundles") or ReplicatedStorage:WaitForChild("NetworkBundles")
	
	return Event
	
end

function NetworkBundle:Fire(...)
	
	table.insert(self.Queue, {...})
	
	self.Setup()
	
end

function NetworkBundle:Connect(func)
	
	local LocalConnection = nil
	local Branch = isServer and "OnServerEvent" or "OnClientEvent"
	
	local function disconnect()
		
		return LocalConnection and LocalConnection:Disconect()
		
	end
	
	LocalConnection = self.Remote[Branch]:Connect(function(...)
		
		func(...)
		table.insert(self.Connections, LocalConnection)
		
	end)
	
	return {Disconnect = disconnect}
end

function NetworkBundle:Destroy()
	table.clear(self.Queue)
	table.clear(self.Connections)
	
	self.Remote:Destroy()
	
	if self.QueueConnection then
		
		self.QueueConnection:Disconnect()
		
	end
	table.clear(self)
	setmetatable(self, nil)
end

local Bundler = {}

function Bundler.new(Name, timer)
	local obj = setmetatable({}, NetworkBundle)
	Setup(timer)
	
	local function fireClient(Player, ...)
		
		return type(Player) == "userdata" and obj.Remote:FireCient(Player, ...) or obj.Remote:FireAllClients(...)
		
	end
	
	local function fireServer(...)
		
		obj.Server:FireServer(...)
		
	end
	
	local function processQueue()
		
		if #obj.Queue == 0 then return end	
		
		local foo = isServer and fireClient or fireServer
		
		for iter, data in ipairs(obj.Queue) do
			
			coroutine.wrap(foo)(unpack(data))
			
		end
		
		obj.Queue = {}
	end
	
	local function setupQueue()
		
		if obj.QueueConnection then return end
		
		obj.QueueConnection = RunService.Heartbeat:Connect(function()
			
			if #obj.Queue == 0 then obj.QueueConnection:Disconnect() return end
			
			processQueue()
			
		end)
	end
	
	local function ClearConnection()
		
		for i, Connection in ipairs(obj.Connections) do
			
			Connection:Disconnect()
			
		end
	end
	
	obj.Queue = {}
	obj.Connections = {}
	obj.Setup = setupQueue
	
	obj.Remote = isServer and createEvent(Name) or ReplicatedStorage.NetworkBundles:WaitForChild(Name, timer)
	
	obj.QueueConnection = RunService.Heartbeat:Connect(function(dt)
		
		processQueue()
		
	end)
	
	return obj
end

return Bundler
