def mapButton($btn):
  if $btn=="tl" then {press:16, release:20}
  elif $btn=="bl" then {press:17, release:21}
  elif $btn=="tr" then {press:19, release:23}
  elif $btn=="br" then {press:18, release:22}
  elif $btn=="top" then {press:100, release:101}
  elif $btn=="bottom" then {press:98, release:99}
  else error("unknown button")
  end;

. as $base
| mapButton($target) as $m
| $base
| .button = $target
| .mapping.short.press  = $m.press
| .mapping.short.release = $m.release
| .mapping.long.press   = $m.press
| .mapping.long.release = $m.release
| .short.name = ($target + " short")
| .long.start.name = ($target + " long start")
| .long.end.name = ($target + " long end")
