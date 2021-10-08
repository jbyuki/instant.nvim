-- Generated using ntangle.nvim
local log_filename
if vim.g.debug_instant then
  log_filename = vim.fn.stdpath('data') .. "/instant.log"
end

local log

function log(...)
  if log_filename then
    vim.schedule(function()
      local elems = { ... }
      for i=1,#elems do
        elems[i] = tostring(elems[i])
      end

      local line table.concat(elems, " ")
        local f = io.open(log_filename, "a")
        if f then
          f:write(line .. "\n")
          f:close()
        end
      end
    end)
  end
end

return log

