{ palette }:

''
  font_family CaskaydiaCove NF
  font_size 12.0

  window_padding_width 16
  background_opacity 1.0
  confirm_os_window_close 0
  enable_audio_bell no
  cursor_shape beam
  cursor_shape_unfocused hollow

  background ${palette.background}
  foreground ${palette.foreground}
  selection_background ${palette.surfaceElevated}
  selection_foreground ${palette.foreground}
  cursor ${palette.focus}
  cursor_text_color ${palette.accentForeground}
  url_color ${palette.accent}

  active_border_color ${palette.focus}
  inactive_border_color ${palette.border}
  bell_border_color ${palette.error}
  active_tab_foreground ${palette.accentForeground}
  active_tab_background ${palette.accent}
  active_tab_font_style bold
  inactive_tab_foreground ${palette.muted}
  inactive_tab_background ${palette.surface}
  inactive_tab_font_style normal
  tab_bar_background ${palette.background}

  color0 ${palette.surface}
  color1 ${palette.error}
  color2 ${palette.success}
  color3 ${palette.warning}
  color4 ${palette.border}
  color5 ${palette.accent}
  color6 ${palette.focus}
  color7 ${palette.foreground}
  color8 ${palette.muted}
  color9 ${palette.error}
  color10 ${palette.success}
  color11 ${palette.warning}
  color12 ${palette.accent}
  color13 ${palette.focus}
  color14 ${palette.focus}
  color15 ${palette.foreground}

  map ctrl+shift+enter new_window_with_cwd
  map ctrl+shift+t new_tab_with_cwd
''
