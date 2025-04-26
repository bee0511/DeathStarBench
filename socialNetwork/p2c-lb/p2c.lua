-- p2c.lua
local _M = {}

local peers = ngx.shared.peers   -- backends
local rif   = ngx.shared.rif_store -- request in flight counters

local function rand_sample(tab, d)
    local picked, seen = {}, {}
    while #picked < d do
        local k = tab[math.random(#tab)]
        if not seen[k] then
            picked[#picked+1] = k
            seen[k] = true
        end
    end
    return picked
end

function _M.init_peers(list)
    for _, url in ipairs(list) do
        peers:set(url, 1)
    end
end

function _M.choose_backend()
    local backends = peers:get_keys()
    local candidates = rand_sample(backends, 2) -- pick 2 servers
    local best, min_rif = nil, math.huge
    for _, backend in ipairs(candidates) do
        local load = rif:get(backend) or 0
        if load < min_rif then
            min_rif = load
            best = backend
        end
    end

    if not best then
        best = candidates[1]
    end

    ngx.ctx.chosen = best
    rif:incr(best, 1, 0)
    ngx.var.backend = "http://" .. best
end

function _M.finish_request()
    local chosen = ngx.ctx.chosen
    if chosen then
        rif:incr(chosen, -1, 0)
    end
end

return _M
