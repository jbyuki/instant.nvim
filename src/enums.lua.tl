@../lua/instant/enums.lua=
local MSG_TYPE = {
@message_types
}
local OP_TYPE = {
@operation_types
}

return {
@export_symbols
}

@export_symbols+=
MSG_TYPE = MSG_TYPE,
OP_TYPE = OP_TYPE,

@message_types+=
TEXT = 1,
AVAILABLE = 2,
REQUEST = 3,
INITIAL = 6,
INFO = 5,
CONNECT = 7,
DISCONNECT = 8,
DATA = 9,

@operation_types+=
DEL = 1,
INS = 2,
