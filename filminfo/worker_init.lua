local work_id = ngx.worker.id()

if work_id == 0 then
    return
end

