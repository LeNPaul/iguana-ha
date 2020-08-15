local server = require "ha.server_class"
local PollerManager = {}

local function isPollingChannel(Channel)
   local ChannelType = Channel.Source:nodeValue()
   return ChannelType ~= "LLP Listener" and ChannelType ~= "From HTTPS" 
   and ChannelType ~= "From Channel" or Channel.Name:S() == "HealthCheck"
end

function PollerManager:isIgnoredChannel(ChannelName)
   for _,IgnoredChannelName in pairs(self.conf.ignored_channels) do
      if ChannelName == IgnoredChannelName or ChannelName == self.conf.channel_name then
         return true
      end
   end
   return false
end

-- Re-initialize the server list if its length is not equal
-- to the expected server count. This can happen if the servers
-- are started at the roughly same time. Once the list has been
-- properly initialized once, it will not be re-initialized again,
-- since this would be a failover, not a bad initialization.
--
-- This depends on the server class not re-creating the .remotes
-- table if it exists already, as well as the Servers object
-- being created globally (not on each run).
--
function PollerManager:fillServersList()
   trace(PollerManagerConf.remotes_count, self.servers.remotesCount)
   if PollerManagerConf.remotes_count ~= self.servers.remotesCount then
      iguana.logDebug("remote count = " .. tostring(self.servers.remotesCount) .. ". (Re)initializing server list.")
      server.fillServerList(self.servers, self.serverFilter)
   else
      trace(self)
      iguana.logDebug("Server list initialized and equal to expected count. Will not reinitializing again.")
   end
end

function PollerManager:new(PollerManagerConf, serverFilter)
   local pm = {}
   pm.conf = PollerManagerConf

   setmetatable(pm, self)
   self.__index = self

   pm.servers = {}
   pm.serverFilter = serverFilter

   pm:fillServersList()

   return pm
end

function PollerManager:hasRunningChannels(RemoteConfig)
   local KeepWaiting = false

   for i=1, RemoteConfig:childCount("Channel") do
      local ChannelConfig = RemoteConfig:child("Channel", i)
      trace(ChannelConfig.Name:S())
      if isPollingChannel(ChannelConfig)
         and ChannelConfig.Status:nodeValue() == "on"
         and not self:isIgnoredChannel(ChannelConfig.Name:nodeValue()) then
         trace("Channels are still running on another " ..
            "wannabe active server.")
         trace(ChannelConfig.Name:nodeValue())
         KeepWaiting = true
         break
      end
   end

   return KeepWaiting
end

function PollerManager:stopChannels()
   iguana.logDebug("This server is INACTIVE. Stop channels.")
   self:doBulkAction("stop")
end

function PollerManager:startChannels()
   iguana.logDebug("This server is ACTIVE. Start channels.")
   self:doBulkAction("start")
end

function PollerManager:wait()
   iguana.logDebug("I am the active server, " ..
      "but I must wait for all remote channels to shutdown.")
end

local function IsAlive(DashboardDataString, ResponseCode)
   if ResponseCode ~= 200 then
      return false
   end

   local ParsedData = json.parse{ data=DashboardDataString }
   local PanicString = ParsedData.PanicErrorString
   if PanicString ~= '' then
      return false
   end

   return true
end

function PollerManager:run()
   local MyWeight = self.conf.weights[self.servers.this.url]
   local IsActive = true
   local KeepWaiting = false
   trace(MyWeight)

   -- If a server is online with a higher weight than us, resign.
   -- Else promote ourself to active server. If the weights are
   -- equal, string compare the URLs to decide the winner.
   for Url, TheServer in pairs(self.servers.remotes) do
      trace(TheServer)
      -- Use dashboard_data to health check since it contains
      -- PanicErrorString, which indicates PANIC MODE.
      local Success, Result, Code = pcall(TheServer.apiCall, 
         TheServer, net.http.get, {
            url = Url .. "/dashboard_data", live = true
         })

      local Success, Alive = pcall(IsAlive, Result, Code)

      if Success and Alive then
         local TheirWeight = self.conf.weights[Url]
         trace(Url, TheirWeight)
         -- This should never be possible.
         if not TheirWeight then
            error("Misconfiguration!!! The remote server " ..
               "is not configured (Make sure the URL matches).")
         end

         if TheirWeight > MyWeight then
            IsActive = false
            break 
         elseif TheirWeight < MyWeight then
            local Success, Result, Code = pcall(TheServer.apiCall, 
               TheServer, net.http.get, {
                  url = Url .. "/status", live = true
               })
            local RemoteConfig = xml.parse{data=Result}.IguanaStatus
            KeepWaiting = self:hasRunningChannels(RemoteConfig)
            break
         elseif TheirWeight == MyWeight then
            if Url > self.servers.this.url then
               IsActive = false
               break
            elseif Url < self.servers.this.url then
               local RemoteConfig = xml.parse{data=Result}.IguanaStatus
               KeepWaiting = self:hasRunningChannels(RemoteConfig)
               break
            else
               error("URLs are the same. This should not be.")
            end
         end
      end
   end

   return IsActive, KeepWaiting
end
--
-- The bulk actions will always be performed on **this** server.
--
function PollerManager:doBulkAction(Action)
   -- Get **this** server's current status.
   local Config = xml.parse{data=iguana.status()}.IguanaStatus

   for i=1, Config:childCount("Channel") do
      local ChannelConfig = Config:child("Channel", i)
      local Guid = ChannelConfig.Guid:nodeValue()
      local ChannelName = ChannelConfig.Name:nodeValue()
      local CurrentStatus = ChannelConfig.Status:nodeValue()
      trace(Action, CurrentStatus)

      local ActionNeeded  = (Action == 'start' and CurrentStatus ~= 'on')
      or (Action == 'stop'  and CurrentStatus ~= 'off')
      trace(ActionNeeded)

      if ActionNeeded
         and isPollingChannel(ChannelConfig)
         and not self:isIgnoredChannel(ChannelName) then

         iguana.logDebug(Action .. "ing channel " .. ChannelName)

         local Result, Code = self.servers.this:apiCall(net.http.post, {
               url = self.servers.this.url .. "/status",
               live = true,
               parameters = {
                  action = Action,
                  name   = ChannelName,
               }
            })
         trace(Result, Code)
      end
   end   
end

return PollerManager
