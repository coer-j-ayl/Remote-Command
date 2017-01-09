local Log     = require("log")
local Socket  = require("lsocket")
local CMD_PDU = require("cmd_pdu")
local PDU     = require("pdu")
local Util    = require("util")

local LOG_TAG = "rd_client"

local function get_real_path (path)
    local cur_path = os.getenv("PWD")
    local abs_path, abs_path_stack, abs_path_stack_len

    if (string.sub(path, 1, 1) == "/") then
        abs_path = path
    else
        abs_path = cur_path.."/"..path
    end

    abs_path_stack     = {}
    abs_path_stack_len = 0
    for file_dir in string.gmatch(abs_path, "[_%w-%.]*/") do
        if (file_dir == "../") then
            abs_path_stack_len = abs_path_stack_len <= 1 and 1 or abs_path_stack_len - 1
        else
            abs_path_stack_len = abs_path_stack_len + 1
            abs_path_stack[abs_path_stack_len] = file_dir
        end
    end

    local last_path = string.match(abs_path, "/[_%w-%.]*$")
    if (last_path ~= nil) then
        abs_path_stack[abs_path_stack_len + 1] = last_path.sub(last_path, 2, -1)
    end

    return table.concat(abs_path_stack)
end

local function get_file_type (suffix)
    local file_type = GLOBAL_CONSTANT_FLAG.FILE_TYPE_NOR

    for tp, tc in pairs(config.file_type_map) do
        local handle = false

        for k, sx in pairs(tc) do
            if (suffix == sx) then
                file_type = tp
                handle    = true
                break
            end
        end

        if (handle == true) then 
            break
        end
    end
end

local function get_remote_gui_cmd (path)
    local cmd  = nil

    if (Util.is_dir(path)) then
        cmd = config.file_open_map[GLOBAL_CONSTANT_FLAG.FILE_TYPE_DIR]
    else
        local suffix = string.match(path, "%.%a+$")
        if (suffix) then
            suffix = string.sub(suffix, 2, -1)
            cmd    = config.file_open_map[get_file_type(suffix)]
        end

        if (not cmd) then
            cmd    = config.file_open_map[GLOBAL_CONSTANT_FLAG.FILE_TYPE_NOR]
        end
    end

    return cmd
end

local function get_share_path (path) 
    local new_path = nil

    for local_dir, share_dir in pairs(config.shared_map) do
        if (string.match(path, "^"..local_dir)) then
            new_path = share_dir..string.sub(path, string.len(local_dir) + 1, -1)
            break
        end
    end

    return new_path
end

-- excute command
local function execute_cmd (cmd, args, cmd_path) 
    local pdu = CMD_PDU.instance(PDU.instance(true))

    pdu:init(GLOBAL_CONSTANT_FLAG.DATA_TYPE_CMD, GLOBAL_CONSTANT_FLAG.MSG_TYPE_REQ)
    pdu:set_flag(GLOBAL_CONSTANT_FLAG.FLAG_NONE)
    pdu:set_cmd(cmd, args, cmd_path)

    local socket = Socket.client(config.server_ip, config.server_port)
    if (socket ~= nil) then
        socket:send(tostring(pdu))
        socket:close()
    end
end

-- open file with remote host gui
local function remote_desk (path)
    local share_file = get_share_path(path)
    local cmd        = get_remote_gui_cmd(path)

    if (share_file == nil or cmd == nil) then
        Log.d(LOG_TAG, "invalid path : "..path)
        return
    end

    execute_cmd(cmd, share_file)
end

local function remote_cmd (tb)
    local cmd  = tb[1]
    local args = nil 

    table.remove(tb, 1)
    args = table.concat(tb, " ")

    local local_path = get_real_path(".")
    local share_path = get_share_path(local_path)

    execute_cmd(cmd, args, share_path)
end

-------------- Main Function ------------------
if (#arg <= 0) then 
    print([[
        rd <command> <args>
        rd <file>]]
    )
    return
end

local handle = false
if (#arg == 1) then
    local path = get_real_path(arg[1])

    if (Util.is_dir(path) or Util.is_file(path)) then
        remote_desk(path)
        handle = true
    end
end

if (handle == false) then
    remote_cmd(arg)
end
