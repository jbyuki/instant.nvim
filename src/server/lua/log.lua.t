##instant_log
@../../../lua/instant/log.lua=
@script_variables
@declare_functions
@functions
return log

@declare_functions+=
local log

@functions+=
function log(...)
  if log_filename then
    vim.schedule(function()
      local elems = { ... }
      for i=1,#elems do
        elems[i] = tostring(elems[i])
      end

      local line table.concat(elems, " ")
        @append_to_log_file
      end
    end)
  end
end

@script_variables+=
local log_filename
if vim.g.debug_instant then
  log_filename = vim.fn.stdpath('data') .. "/instant.log"
end

@append_to_log_file+=
local f = io.open(log_filename, "a")
if f then
  f:write(line .. "\n")
  f:close()
end
