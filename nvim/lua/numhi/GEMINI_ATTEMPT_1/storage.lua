-- ~/.config/nvim/lua/numhi/storage.lua

local utils = require("numhi.utils")
local api = vim.api
local fn = vim.fn

local M = {}

-- Internal helper to get the full path to a specific data file (highlights or notes)
---@param file_type "highlights" | "notes"
---@param plugin_config table The NumHi plugin's current configuration.
---@param project_root_override string? Optional project root to use instead of auto-detecting.
---@return string|nil Path to the data file, or nil if project root cannot be determined.
local function get_data_file_path(file_type, plugin_config, project_root_override)
  local project_root = project_root_override or utils.get_project_root()
  if not project_root then
    utils.notify_message("NumHi: Could not determine project root for storage.", vim.log.levels.WARN)
    return nil
  end

  local storage_dir = project_root .. "/" .. plugin_config.storage_dir_name
  if not utils.ensure_dir_exists(storage_dir) then
    utils.notify_message("NumHi: Could not create storage directory: " .. storage_dir, vim.log.levels.ERROR)
    return nil
  end

  local file_name
  if file_type == "highlights" then
    file_name = plugin_config.highlights_file_name
  elseif file_type == "notes" then
    file_name = plugin_config.notes_file_name
  else
    utils.notify_message("NumHi: Unknown data file type requested: " .. file_type, vim.log.levels.ERROR)
    return nil
  end

  return storage_dir .. "/" .. file_name
end

--- Reads data from a JSON file.
---@param file_path string Full path to the JSON file.
---@return table Parsed JSON data as a Lua table, or an empty table on error/file not found.
local function read_json_file(file_path)
  if fn.filereadable(file_path) == 0 then
    return {} -- File doesn't exist, return empty data
  end

  local content_lines, read_err = fn.readfile(file_path, "b") -- Read as binary to handle potential encoding issues better
  if read_err or not content_lines then
    utils.notify_message("NumHi: Error reading file: " .. file_path .. (read_err and (": " .. read_err) or ""), vim.log.levels.ERROR)
    return {}
  end
  
  local content_str = table.concat(content_lines, "\n")
  if content_str == "" then return {} end -- Empty file

  local ok, data = pcall(fn.json_decode, content_str)
  if not ok or type(data) ~= "table" then
    utils.notify_message("NumHi: Error decoding JSON from " .. file_path .. (data and (": " .. tostring(data)) or ""), vim.log.levels.ERROR)
    -- Potentially try to back up the corrupted file here
    return {}
  end
  return data
end

--- Writes data to a JSON file.
---@param file_path string Full path to the JSON file.
---@param data table Lua table to serialize and write.
---@return boolean True on success, false on failure.
local function write_json_file(file_path, data)
  local json_string, encode_err = pcall(fn.json_encode, data)
  if not json_string or encode_err then -- encode_err will be true if pcall caught an error
     utils.notify_message("NumHi: Error encoding data to JSON for " .. file_path .. (encode_err and (": " .. tostring(encode_err)) or ""), vim.log.levels.ERROR)
    return false
  end

  -- Atomically write by writing to a temp file then renaming
  local temp_file_path = file_path .. ".tmp"
  local write_ok, write_err = pcall(fn.writefile, {json_string}, temp_file_path, "b")

  if not write_ok then
    utils.notify_message("NumHi: Error writing to temporary file: " .. temp_file_path .. (write_err and (": " .. tostring(write_err)) or ""), vim.log.levels.ERROR)
    fn.delete(temp_file_path) -- Attempt to clean up temp file
    return false
  end

  -- Rename temp file to actual file path
  -- On Windows, os.rename might fail if the destination exists.
  -- Lua's os.rename behavior is platform-dependent for overwriting.
  -- A safer approach might be to delete original then rename, or use platform-specific move.
  -- For now, let's assume os.rename overwrites or Neovim's fn.rename handles it.
  -- fn.rename() is not available in Lua 5.1 context directly without vim.loop or os.rename
  local rename_ok, rename_err
  if fn.has("win32") then
    -- On Windows, delete target first if it exists
    if fn.filereadable(file_path) == 1 then
      fn.delete(file_path)
    end
  end
  rename_ok, rename_err = pcall(fn.rename, temp_file_path, file_path)
  
  if not rename_ok then
     utils.notify_message("NumHi: Error renaming temp file to " .. file_path .. (rename_err and (": " .. rename_err) or ""), vim.log.levels.ERROR)
    fn.delete(temp_file_path) -- Attempt to clean up temp file
    return false
  end

  return true
end

--- Loads all highlights for the current project.
---@param plugin_config table The NumHi plugin's current configuration.
---@return table A table mapping buffer paths to their highlight data.
function M.load_all_highlights(plugin_config)
  local highlights_file = get_data_file_path("highlights", plugin_config)
  if not highlights_file then return {} end
  return read_json_file(highlights_file)
end

--- Saves all highlights for the current project.
---@param all_highlights_data table Data for all highlights in the project.
---@param plugin_config table The NumHi plugin's current configuration.
---@return boolean Success status.
function M.save_all_highlights(all_highlights_data, plugin_config)
  local highlights_file = get_data_file_path("highlights", plugin_config)
  if not highlights_file then return false end
  return write_json_file(highlights_file, all_highlights_data)
end

--- Loads all notes for the current project.
---@param plugin_config table The NumHi plugin's current configuration.
---@return table A table mapping note UUIDs to their note data.
function M.load_all_notes(plugin_config)
  local notes_file = get_data_file_path("notes", plugin_config)
  if not notes_file then return {} end
  return read_json_file(notes_file)
end

--- Saves all notes for the current project.
---@param all_notes_data table Data for all notes.
---@param plugin_config table The NumHi plugin's current configuration.
---@return boolean Success status.
function M.save_all_notes(all_notes_data, plugin_config)
  local notes_file = get_data_file_path("notes", plugin_config)
  if not notes_file then return false end
  return write_json_file(notes_file, all_notes_data)
end


--- Gets the buffer-specific key for storing/retrieving highlights.
--- Currently uses the full buffer path.
--- Returns nil if buffer is not associated with a file.
---@param bufnr number Buffer handle (0 for current).
---@return string|nil Buffer path or nil.
function M.get_buffer_storage_key(bufnr)
  bufnr = bufnr or 0
  local buf_name = api.nvim_buf_get_name(bufnr)
  if buf_name == "" then
    -- For unnamed buffers, we might not save, or save under a special key if desired.
    -- For now, only save for named buffers.
    return nil
  end
  return fn.fnamemodify(buf_name, ":p") -- Get full path
end


-- Example of how these might be integrated into plugin state management:
-- (This part would typically be in core.lua or init.lua)
--
-- local plugin_state = {
--   highlights_by_buffer = {}, -- Keyed by full buffer path
--   notes_by_id = {},          -- Keyed by note_uuid
--   config = {},               -- Loaded plugin config
-- }
--
-- function load_for_buffer(bufnr)
--   local buffer_key = M.get_buffer_storage_key(bufnr)
--   if not buffer_key then return end
--
--   -- This assumes highlights_by_buffer and notes_by_id are already populated
--   -- for the entire project by an initial load call (e.g., in plugin setup).
--   -- Or, if loading lazily per buffer from separate files:
--   -- plugin_state.highlights_by_buffer[buffer_key] = M.load_highlights_for_buffer_file(buffer_key, plugin_state.config)
--   -- apply_extmarks_from_loaded_data(bufnr, plugin_state.highlights_by_buffer[buffer_key] or {})
-- end

-- function save_all_data_for_project()
--   M.save_all_highlights(plugin_state.highlights_by_buffer, plugin_state.config)
--   M.save_all_notes(plugin_state.notes_by_id, plugin_state.config)
-- end

return M

