local core = require("apisix.core")

local schema = {
  type = "object",
  properties = {
    claim  = { type = "string", default = "sub" },
    jwt_consumers = {
        type = "array",
        items = { type = "string" },
        default = core.json.array_mt and setmetatable({}, core.json.array_mt) or {},
    }
  },
}

local _M = {
  version  = 0.1,
  priority = 2505,  -- just below jwt-auth (2510): runs after it in rewrite
  name     = "tenant-identity",
  schema   = schema,
}

function _M.check_schema(conf)
  return core.schema.check(schema, conf)
end

local function decode_payload(ctx)
  local auth = core.request.header(ctx, "Authorization") or ""
  local token = auth:match("^[Bb]earer%s+(.+)$") or auth
  local p = token:match("^[^.]+%.([^.]+)%.")
  if not p then return nil end
  p = p:gsub("%-", "+"):gsub("_", "/")
  if #p % 4 > 0 then p = p .. string.rep("=", 4 - #p % 4) end
  return core.json.decode(ngx.decode_base64(p) or "")
end

local function is_jwt_consumer(conf, consumer)
  for _, name in ipairs(conf.jwt_consumers) do
    if consumer.username == name then return true end
  end
  return false
end

local function debug_state(phase, ctx, extra)
  core.log.warn("tenant-identity ", phase,
    ": consumer=", ctx.consumer and ctx.consumer.username or "<none>",
    ", consumer_name=", ctx.consumer_name or "<none>",
    ", tenant=", ctx.tenant or "<none>",
    extra and (", " .. extra) or "")
end

-- rewrite: signature already verified by jwt-auth; extract and validate the tenant
function _M.rewrite(conf, ctx)
--   debug_state("rewrite:start", ctx)
  if #conf.jwt_consumers == 0 then return end
  if not ctx.consumer or not is_jwt_consumer(conf, ctx.consumer) then
    return -- unauthenticated or non-JWT consumer: leave untouched
  end
  local payload = decode_payload(ctx)
  local tenant = payload and payload[conf.claim]
  local prefix = ctx.consumer.username
  if type(tenant) ~= "string" or tenant == "" then
    return 401, { message = "missing " .. conf.claim .. " claim" }
  end
  ctx.tenant = prefix .. ":" .. tenant
end

-- access: consumer config merge is done; swap identity on a per-request copy
function _M.access(conf, ctx)
--   debug_state("access:start", ctx)
  if not ctx.tenant then return end
  local name = ctx.tenant
  local consumer = core.table.clone(ctx.consumer)
  consumer.username = name
  consumer.consumer_name = name
  ctx.consumer = consumer
  ctx.consumer_name = name
  ctx.var.consumer_name = name
  core.request.set_header(ctx, "X-Consumer-Username", name)
end

return _M