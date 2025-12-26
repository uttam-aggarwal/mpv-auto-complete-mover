local mp = require "mp"
local utils = require "mp.utils"

-- ================= CONFIG =================
local TOGGLE_KEY = "ctrl+b"
local OSD_TIME = 2

-- ================= PATHS =================
local state_dir  = mp.command_native({"expand-path", "~~/state"})
local log_path   = utils.join_path(state_dir, "move_to_completed.log")
local flag_path  = utils.join_path(state_dir, "move_to_completed.enabled")
local debug_path = utils.join_path(state_dir, "move_to_completed_debug.log")

-- ================= STATE =================
local current_file = nil

-- ================= DEBUG =================
local function debug(msg)
    local f = io.open(debug_path, "a")
    if f then
        f:write(os.date("[%Y-%m-%d %H:%M:%S] ") .. msg .. "\n")
        f:close()
    end
    mp.msg.info(msg)
end

-- ================= INIT =================
utils.subprocess({ args = {"cmd", "/c", "mkdir", state_dir}, cancellable = false })

-- 🔒 FORCE DISABLED ON MPV START
os.remove(flag_path)

debug("SCRIPT LOADED (toggle reset to OFF)")

-- ================= ENABLE FLAG =================
local function is_enabled()
    return utils.file_info(flag_path) ~= nil
end

local function set_enabled(val)
    if val then
        local f = io.open(flag_path, "w")
        if f then f:write("on") f:close() end
    else
        os.remove(flag_path)
    end
end

-- ================= LOG HELPERS =================
local function ensure_log_file()
    local f = io.open(log_path, "a")
    if f then f:close() end
end

local function append_log(path)
    ensure_log_file()
    local f = io.open(log_path, "a")
    if f then
        f:write(path .. "\n")
        f:close()
        debug("LOG APPEND: " .. path)
    end
end

local function read_log()
    local f = io.open(log_path, "r")
    if not f then return {} end
    local t = {}
    for line in f:lines() do
        if line ~= "" then t[#t+1] = line end
    end
    f:close()
    return t
end

local function write_log(entries)
    if #entries == 0 then
        os.remove(log_path)
        debug("LOG CLEARED")
        return
    end
    local f = io.open(log_path, "w")
    if not f then return end
    for _, l in ipairs(entries) do
        f:write(l .. "\n")
    end
    f:close()
end

-- ================= FILE HELPERS =================
local function path_exists(p)
    return utils.file_info(p) ~= nil
end

local function unique_path(path)
    if not path_exists(path) then return path end
    local dir, name = utils.split_path(path)
    local base, ext = name:match("^(.*)%.(.*)$")
    if not base then base = name ext = "" else ext = "."..ext end
    local i = 1
    while true do
        local c = utils.join_path(dir, base.." ("..i..")"..ext)
        if not path_exists(c) then return c end
        i = i + 1
    end
end

-- ================= TOGGLE =================
local function toggle()
    local new = not is_enabled()
    set_enabled(new)
    mp.osd_message(
        new and "Move to completed: ON" or "Move to completed: OFF",
        OSD_TIME
    )
    debug("TOGGLE -> " .. tostring(new))
end

mp.add_key_binding(TOGGLE_KEY, "toggle_move_to_completed", toggle)

-- ================= PROCESS LOG =================
local function process_log()
    local entries = read_log()
    if #entries == 0 then
        debug("NO LOG ENTRIES TO PROCESS")
        return
    end

    local keep = {}

    for _, path in ipairs(entries) do
        debug("PROCESS LOG ENTRY: " .. path)

        if not path_exists(path) then
            debug("STALE ENTRY REMOVED")
        else
            local dir, file = utils.split_path(path)
            dir = dir:gsub("[/\\]$", "")
            local parent = dir:match("([^/\\]+)$")

            if parent and parent:lower() == "completed" then
                debug("ALREADY IN COMPLETED, SKIPPED")
            else
                local target_dir = utils.join_path(dir, "completed")
                utils.subprocess({
                    args = {"cmd", "/c", "mkdir", target_dir},
                    cancellable = false
                })

                local dest = unique_path(
                    utils.join_path(target_dir, file)
                )

                utils.subprocess({
                    args = {"cmd", "/c", "move", "/Y", path, dest},
                    cancellable = false
                })

                if path_exists(dest) then
                    debug("MOVED SUCCESSFULLY: " .. dest)
                else
                    debug("MOVE FAILED, WILL RETRY")
                    keep[#keep + 1] = path
                end
            end
        end
    end

    write_log(keep)
end

-- ================= CAPTURE CURRENT FILE =================
mp.register_event("file-loaded", function()
    local path = mp.get_property("path")
    if path and not path:match("^%a+://") then
        current_file = path
        debug("CAPTURED CURRENT FILE: " .. path)
    else
        current_file = nil
    end

    process_log()
end)

-- ================= RECORD COMPLETION =================
mp.register_event("end-file", function(e)
    debug("END-FILE reason=" .. tostring(e.reason))
    if e.reason ~= "eof" then return end
    if not is_enabled() then return end
    if not current_file then return end

    append_log(current_file)
end)

-- ================= CLEANUP ON EXIT =================
mp.register_event("shutdown", function()
    debug("SHUTDOWN EVENT – toggle reset to OFF")
    os.remove(flag_path)
    process_log()
end)
