-- prequal.lua
-- Lua module implementing a simple Prequal-style load balancer for OpenResty

local _M = {}
-- Shared dictionaries for tracking requests-in-flight (RIF), round-trip time (RTT),
-- quantile thresholds for hot-cold split, and the list of peer backends.
local rif   = ngx.shared.rif_store
local rtt   = ngx.shared.rtt_store
local q     = ngx.shared.q_stats
local peers = ngx.shared.peers

------------------ UTILITIES ------------------------------------------------
-- Randomly sample 'd' unique elements from 'tab'.
local function rand_sample(tab, d)
    local picked, seen = {}, {}
    while #picked < d do
        local k = tab[ math.random(#tab) ]
        if not seen[k] then
            picked[#picked+1] = k
            seen[k] = true
        end
    end
    return picked
end

------------------ BACKGROUND PROBE TIMER -----------------------------------
-- Asynchronously probes each backend by measuring TCP connection latency.
-- 'premature' indicates if the timer was prematurely aborted.
local function probe_once(premature)
    if premature then return end

    for _, url in ipairs(peers:get_keys()) do
        -- Each peer entry uses the format "host:port".
        local host, port = url:match("^([^:]+):(%d+)$")
        local sock = ngx.socket.tcp()
        sock:settimeout(200)  -- timeout in milliseconds

        local start = ngx.now()
        local ok, err = sock:connect(host, tonumber(port))
        local delta = ngx.now() - start

        if ok then
            sock:close()
            -- Record the measured RTT for this peer.
            rtt:set(url, delta)
        else
            -- On connection failure, assign a high RTT penalty.
            rtt:set(url, 10)
        end
    end

    -- Schedule the next probe after 200ms.
    ngx.timer.at(0.2, probe_once)
end

------------------ PUBLIC API ------------------------------------------------
-- Initializes the peer list and starts the probing timer.
-- 'list' should be an array of strings: {"host:port", ...}.
function _M.init_peers(list)
    for _, url in ipairs(list) do
        peers:set(url, 1)
    end
    -- Kick off the first probe immediately.
    ngx.timer.at(0, probe_once)
end

-- Selects a backend using the hot-cold lexicographic rule based on RIF and RTT.
function _M.choose_backend()
    local backends = peers:get_keys()
    local probes   = rand_sample(backends, 3)  -- sample d=3 backends

    -- Compute the RIF threshold at the 80th percentile occasionally.
    local hot_cut = q:get("cut") or 1
    if math.random(20) == 1 then
        local vals = {}
        for _, b in ipairs(backends) do
            vals[#vals+1] = rif:get(b) or 0
        end
        table.sort(vals)
        hot_cut = vals[ math.ceil(0.8 * #vals) ] or 1
        q:set("cut", hot_cut)
    end

    -- Determine best backend: prefer 'cold' (RIF <= threshold) with lowest RTT;
    -- if all are hot, pick the one with smallest RIF.
    local best, best_val = nil, math.huge
    local found_cold    = false
    for _, b in ipairs(probes) do
        local r = rif:get(b) or 0
        local l = rtt:get(b) or 1
        local is_hot = r > hot_cut

        if not is_hot then
            found_cold = true
            if l < best_val then
                best, best_val = b, l
            end
        elseif not found_cold and r < best_val then
            best, best_val = b, r
        end
    end

    -- Fallback to first sampled backend if none chosen
    if not best then
        best = probes[1]
    end

    -- Mark the chosen backend and increment its RIF counter.
    ngx.ctx.chosen = best
    rif:incr(best, 1, 0)
    -- Prepend 'http://' so proxy_pass can work correctly
    ngx.var.backend = "http://" .. best
end

-- Records observed latency in the header_filter phase.
function _M.note_latency()
    local chosen = ngx.ctx.chosen
    if not chosen then return end
    local now   = ngx.now()
    local start = ngx.req.start_time()
    rtt:set(chosen, now - start)
end

-- Decrements the RIF counter in the log phase after the request completes.
function _M.finish_request()
    local chosen = ngx.ctx.chosen
    if chosen then
        rif:incr(chosen, -1, 0)
    end
end

return _M
