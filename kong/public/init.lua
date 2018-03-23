local require  = require
local meta     = require "kong.meta"


local tonumber = tonumber
local tostring = tostring
local ipairs   = ipairs
local pcall    = pcall
local match    = string.match
local find     = string.find
local fmt      = string.format
local sub      = string.sub


local NAME = meta._NAME .. " public api"

local VERSIONS = {
  "1.0.0",
  "1.0.1",
}

local APIS = {
  "cache",
  "configuration",
  "ctx",
  "dao",
  "db",
  "dns",
  "http",
  "ipc",
  "log",
  "request",
  "response",
  "shm",
  "timers",
  "utils",
  "upstream",
  "upstream.response",
}

local COMPATIBLE_VERSIONS = {}
local LATEST_VERSION


local function parse_version(version)
  local major, minor, patch

  local s1 = find(version, ".", 1, true)

  if not s1 then
    if not match(version, "^%d+$") then
      return
    end

    return tonumber(version), nil, nil
  end

  major = sub(version, 1, s1 - 1)
  if not match(major, "^%d+$") then
    return
  end

  major = tonumber(major)

  local s2 = find(version, ".", s1 + 1, true)
  if not s2 then
    minor = sub(version, s1 + 1)
    if not match(minor, "^%d+$") then
      return
    end

    return major, tonumber(minor), nil
  end

  minor = sub(version, s1 + 1, s2 - 1)
  if not match(minor, "^%d+$") then
    return
  end

  minor = tonumber(minor)

  patch = sub(version, s2 + 1)
  if not match(patch, "^%d+$") then
    return
  end

  patch = tonumber(patch)

  return major, minor, patch
end


local function load_api(major, minor, patch)
  local version

  if major and minor and patch then
    version = fmt("%u.%u.%u", major, minor, patch)

  elseif major and minor then
    version = fmt("%u.%u", major, minor, patch)

  elseif major then
    version = major

  else
    return LATEST_VERSION
  end

  local api = COMPATIBLE_VERSIONS[version]
  if not api then
    return nil, 'invalid ' .. NAME .. ' version "' .. tostring(version) .. '"'
  end

  return api
end


local function set_api_meta(major, minor, patch, name, found, api)
  if not found then
    return
  end

  api._NAME        = name
  api._VERSION     = fmt("%u.%u.%u", major, minor, patch)
  api._VERSION_NUM = tonumber(fmt("%02u%02u%02u", major, minor, patch))

  api.v = function(major, minor, patch)
    local apis, err = load_api(major, minor, patch)
    if not apis then
      return nil, err
    end

    if not apis[name] then
      return nil, NAME .. ' "' .. name .. '" (' .. api._VERSION .. ") was not found"
    end

    return apis[name]
  end

  return api
end


local function require_api(major, minor, patch, compatible, name)
  local module = fmt("kong.public.%02u.%02u.%02u.%s", major, minor, patch, name)
  local api = set_api_meta(major, minor, patch, name, pcall(require, module))
  if api then
    return api
  end

  if compatible[name] then
    return compatible[name]
  end

  module = fmt("kong.public.%02u.%02u.%s", major, minor, name)
  api = set_api_meta(major, minor, 0, name, pcall(require, module))
  if api then
    return api
  end

  module = fmt("kong.public.%02u.%s", major, name)
  api = set_api_meta(major, 0, 0, name, pcall(require, module))
  if api then
    return api
  end
end


local function require_apis(major, minor, patch, compatible)
  local apis = { v = load_api }
  for _, name in ipairs(APIS) do
    apis[name] = require_api(major, minor, patch, compatible, name)
  end
  return apis
end


do
  for _, version in ipairs(VERSIONS) do
    local major, minor, patch = parse_version(version)

    major = major or 0
    minor = minor or 0
    patch = patch or 0

    local apis = require_apis(major, minor, patch, COMPATIBLE_VERSIONS[major] or {})
    local apis_version_str = fmt("%02u%02u%02u", major, minor, patch)

    apis._NAME        = NAME
    apis._VERSION     = meta._VERSION
    apis._VERSION_NUM = tonumber(fmt("%02u%02u%02u", meta._VERSION_TABLE.major,
                                                     meta._VERSION_TABLE.minor,
                                                     meta._VERSION_TABLE.patch))
    apis._API_VERSION     = version
    apis._API_VERSION_NUM = tonumber(apis_version_str)

    COMPATIBLE_VERSIONS[apis._API_VERSION_NUM]   = apis
    COMPATIBLE_VERSIONS[apis._API_VERSION]       = apis
    COMPATIBLE_VERSIONS[apis_version_str]        = apis
    COMPATIBLE_VERSIONS[major]                   = apis
    COMPATIBLE_VERSIONS[tostring(major)]         = apis
    COMPATIBLE_VERSIONS[major .. "." .. minor]   = apis

    LATEST_VERSION = apis
  end
end


return LATEST_VERSION
