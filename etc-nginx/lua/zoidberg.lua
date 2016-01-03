local json     = require("cjson.safe")
local math     = require("math")
local balancer = require("ngx.balancer")
local resolver = require("resty.dns.resolver")
local lock     = require("resty.lock")
local sha1     = require("resty.sha1")
local string   = require("resty.string")

local _M = { _VERSION = '0.5.0' }
local mt = { __index = _M }

local function stateFromInput(input)
  local apps = {}

  for name, app in pairs(input.apps) do
    apps[name] = {
      servers = {},
    }

    for _, server in ipairs(app.servers) do
      if input.state.versions[name] then
        if input.state.versions[name][server.version] then
          if input.state.versions[name][server.version].weight > 0 then
            table.insert(apps[name].servers, {
              host   = server.host,
              port   = server.port,
              weight = input.state.versions[name][server.version].weight,
            })
          end
        end
      elseif server.version == "1" then
        table.insert(apps[name].servers, {
          host   = server.host,
          port   = server.port,
          weight = 1,
        })
      end
    end
  end

  return apps
end

local function appVersion(app)
  local sha = sha1:new()
  if not sha then
    return nil, "failed to create sha instance"
  end

  -- TODO: this is unstable serialization
  local str, err = json.encode(app)
  if err then
    return nil, err
  end

  sha:update(str)

  return string.to_hex(sha:final())
end

local function unlocked(l, cause)
  local _, err = l:unlock()
  if err then
    ngx.log(ngx.ERR, "error unlocking lock:" .. err)
  end

  return cause
end

function _M.new(_, apps_dict, locks_dict, dump_path, nameservers)
  local apps = ngx.shared[apps_dict]
  if not apps then
    return nil, "apps dictionary " .. apps_dict .. " not found"
  end

  local locks = ngx.shared[locks_dict]
  if not locks then
    return nil, "locks dictionary " .. locks_dict .. " not found"
  end

  local self = {
    apps_dict   = apps_dict,
    locks_dict  = locks_dict,
    dump_path   = dump_path,
    nameservers = nameservers,
  }

  return setmetatable(self, mt)
end

function _M.getResolver(self)
  if not self.resolver then
    if not self.nameservers then
      return nil, "nameservers are not supplied"
    end

    local dns, err = resolver:new({
      nameservers = self.nameservers,
    })

    if err then
      return nil, err
    end

    self.resolver = dns
  end

  return self.resolver
end

function _M.updateApp(self, group, name, app)
  if table.getn(app.servers) == 0 then
    return
  end

  local version, err = appVersion(app)
  if err then
    return err
  end

  local prev, err = self:getApp(name)
  if err then
    return err
  end

  if prev and prev.version == version and prev.group == group then
    return
  end

  local dns, err = self:getResolver()
  if err then
    return err
  end

  for _, server in ipairs(app.servers) do
    if server.host:match("(%d+)%.(%d+)%.(%d+)%.(%d+)") then
      server.addr = server.host
    else
      local addrs, err = dns:query(server.host, {
        qtype = dns.TYPE_A,
      })
      if err then
        return err
      end

      if table.getn(addrs) == 0 then
        return "dns query for " .. server.host .. " retured zero results"
      end

      server.addr = addrs[1].address
    end
  end

  local l = lock:new(self.locks_dict, {
    exptime  = 10,
    timeout  = 5,
    step     = 0.01,
    ratio    = 2,
    max_step = 0.1,
  })

  local _, err = l:lock(name)
  if err then
    return err
  end

  prev, err = self:getApp(name)
  if err then
    return unlocked(l, err)
  end

  if prev and prev.version == version and prev.group == group then
    return unlocked(l)
  end

  err = self:updateAppShared(group, version, name, app)
  if err then
    return unlocked(l, err)
  end

  err = self:updateAppFile(group, version, name, app)
  if err then
    return unlocked(l, err)
  end

  ngx.log(ngx.NOTICE, "updated " .. name .. " (" .. group .. ") with " .. table.getn(app.servers) .. " upstreams")

  return unlocked(l)
end

function _M.updateAppShared(self, group, version, name, app)
  local current = {
    group   = group,
    version = version,
    name    = name,
    app     = app,
  }

  for _, server in ipairs(app.servers) do
    if not server.host then
      return "null host for server"
    end

    if not server.port then
      return "null port for server"
    end

    if not server.weight then
      return "null weight for server"
    end

    if not server.addr then
      return "null addr for server"
    end
  end

  local current_serialized, err = json.encode(current)
  if err then
    return err
  end

  local _, err = ngx.shared[self.apps_dict]:set(name, current_serialized)
  if err then
    return err
  end
end

function _M.updateAppFile(self, group, version, name, app)
  local dump, err = json.encode({
    group   = group,
    version = version,
    name    = name,
    app     = app,
  })
  if err then
    return err
  end

  if not self.dump_path then
    return "dump path is not supplied"
  end

  local file, err = io.open(self.dump_path .. "/" .. name .. ".json", "w")
  if err then
    return err
  end

  -- TOOD: not sure how to check errors here
  file:write(dump .. "\n")
  io.close(file)
end

function _M.readAppFile(self, file)
  if not self.dump_path then
    return "dump path is not supplied"
  end

  local dump, err = io.open(self.dump_path .. "/" .. file)
  if err then
    return err
  end

  local str, err = dump:read("*all")
  io.close(dump)
  if err then
    return err
  end

  local input, err = json.decode(str)
  if err then
    return err
  end

  return self:updateAppShared(input["group"], input["version"], input["name"], input["app"])
end

function _M.updateState(self, group, input)
  local state = stateFromInput(input)

  for name, app in pairs(state) do
    err = self:updateApp(group, name, app)
    if err then
      err = "error updating state for app " .. name .. " of group " .. group .. ": " .. err
    end
  end

  if err then
    return err
  end
end

function _M.getApp(self, name)
  local serialized = ngx.shared[self.apps_dict]:get(name)
  if serialized then
    return json.decode(serialized)
  end
end

function _M.init(apps_dict, locks_dict, dump_path)
  if not dump_path then
    return nil, "dump path is not supplied"
  end

  local zoidberg, err = _M:new(apps_dict, locks_dict, dump_path)
  if err then
    ngx.log(ngx.ERR, "error creating zoidberg instance: " .. err)
    return
  end

  for file in io.popen('ls "' .. dump_path .. '"'):lines() do
    ngx.log(ngx.NOTICE, "restoring app state from file " .. file)
    local err = zoidberg:readAppFile(file)
    if err then
      ngx.log(ngx.ERR, "error reading dump file " .. file .. ": " .. err)
    end
  end
end

function _M.handle(apps_dict, locks_dict, dump_path, nameservers)
  local zoidberg, err = _M:new(apps_dict, locks_dict, dump_path, nameservers)
  if err then
    ngx.log(ngx.ERR, "error creating zoidberg instance: " .. err)
    ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
  end

  local group = ngx.var.zoidberg_group
  if not group then
    ngx.log(ngx.ERR, "zoidberg group is not supplied")
    ngx.exit(ngx.HTTP_NOT_FOUND)
  end

  if ngx.req.get_method() == "PUT" or ngx.req.get_method() == "POST" then
    ngx.req.read_body()

    local input, err = json.decode(ngx.req.get_body_data())
    if err then
      ngx.log("error decoding input json for group " .. group .. ": " .. err)
      ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end

    local err = zoidberg:updateState(group, input)
    if err then
      ngx.log(ngx.ERR, "error updating state for group " .. group .. ": " .. err)
      ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end
  else
    return ngx.exit(ngx.HTTP_BAD_REQUEST)
  end
end

function _M.balance(apps_dict, locks_dict)
  local name = ngx.var.zoidberg_app
  if not name then
    ngx.log(ngx.ERR, "$zoidberg_app is not specified")
    return
  end

  if not ngx.ctx.tries then
    local zoidberg, err = _M:new(apps_dict, locks_dict)
    if err then
      ngx.log(ngx.ERR, "error creating zoidberg instance: " .. err)
      return
    end

    local app, err = zoidberg:getApp(name)
    if err then
      ngx.log(ngx.ERR, "error getting app " .. name .. ": " .. err)
      return
    end

    if not app or table.getn(app.app.servers) == 0 then
      ngx.log(ngx.ERR, "app " .. name .. " is not know or has no known instances")
      return
    end

    ngx.ctx.tries   = 0
    ngx.ctx.servers = app.app.servers
    ngx.ctx.offset  = math.random(1, table.getn(ngx.ctx.servers))
  end

  if ngx.ctx.tries < table.getn(ngx.ctx.servers) then
    -- ask for more tries here
    balancer.set_more_tries(1)
  end

  local index    = (ngx.ctx.offset + ngx.ctx.tries) % table.getn(ngx.ctx.servers) + 1
  local upstream = ngx.ctx.servers[index]

  ngx.ctx.tries = ngx.ctx.tries + 1

  local _, err = balancer.set_current_peer(upstream.addr, upstream.port)
  if err then
    ngx.log(ngx.ERR, "failed to set current peer for app " .. name .. ": " .. err)
    return
  end
end

return _M
