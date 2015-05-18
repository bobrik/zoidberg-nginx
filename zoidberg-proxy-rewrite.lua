local host = ngx.req.get_headers()["Host"]
if not host then
    ngx.exit(ngx.HTTP_BAD_REQUEST)
    return
end

if ngx.shared.zoidberg_state then
    if ngx.shared.zoidberg_state.enabled then
        if ngx.shared.zoidberg_state.enabled[host] then
            -- all good
            return
        end
    end
end

ngx.exit(ngx.HTTP_SERVICE_UNAVAILABLE)
