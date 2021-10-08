##../instant_client
@script_variables+=
local log_filename
if vim.g.instant_log then
  log_filename = vim.fn.stdpath("data") .. "/instant.log"
end

@declare_functions+=
local log

@functions+=
function log(str)
  if log_filename then
    @write_to_logfile
  end
end

@write_to_logfile+=
local f = io.open(log_filename, "a")
if f then
  f:write(str .. "\n")
  f:close()
end
