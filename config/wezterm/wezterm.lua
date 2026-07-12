local wezterm = require("wezterm")
local act = wezterm.action

local config = wezterm.config_builder()

local is_macos = wezterm.target_triple:find("apple-darwin", 1, true) ~= nil

-- Appearance ----------------------------------------------------------------
config.color_scheme = "Tokyo Night"
config.colors = {
  cursor_bg = "#ff2c6d",
  cursor_border = "#ff2c6d",
  cursor_fg = "#1a1b26",
}
config.default_cursor_style = "BlinkingBlock"

config.font = wezterm.font_with_fallback({
  "Fira Code",
  "Hiragino Sans",
  "Noto Sans CJK JP",
})
config.font_size = 14.0

config.window_background_opacity = 0.80
if is_macos then
  config.macos_window_background_blur = 20
end

config.window_decorations = "RESIZE"
config.window_padding = { left = 0, right = 0, top = 0, bottom = 0 }
config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = false

config.front_end = "WebGpu"
config.max_fps = 120

-- Behavior ------------------------------------------------------------------
config.use_ime = true
config.audible_bell = "Disabled"
config.scrollback_lines = 10000

-- Keys ----------------------------------------------------------------------
-- tmux を併用するため分割・タブ系のバインドは持たない
config.keys = {
  { key = "k", mods = "CMD", action = act.ClearScrollback("ScrollbackAndViewport") },
  { key = "b", mods = "CMD|SHIFT", action = act.EmitEvent("toggle-opacity") },
}

wezterm.on("toggle-opacity", function(window, _)
  local overrides = window:get_config_overrides() or {}
  if overrides.window_background_opacity then
    overrides.window_background_opacity = nil
  else
    overrides.window_background_opacity = 1.0
  end
  window:set_config_overrides(overrides)
end)

return config
