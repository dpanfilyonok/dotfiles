# Paths of the global skillshare layer, resolved the way skillshare resolves
# them. Sourced by the install script and the version check.

# skillshare_home prints the global config directory: $XDG_CONFIG_HOME when
# set, %APPDATA% on Windows, ~/.config elsewhere.
skillshare_home() {
  if [ -n "${XDG_CONFIG_HOME:-}" ]; then
    printf '%s/skillshare\n' "$XDG_CONFIG_HOME"
  elif [ -n "${APPDATA:-}" ] && command -v cygpath >/dev/null 2>&1; then
    printf '%s/skillshare\n' "$(cygpath -u "$APPDATA")"
  else
    printf '%s/.config/skillshare\n' "$HOME"
  fi
}

# global_metadata prints the registry of installed global skills. skillshare
# keeps source, ref, commit and tree hash of every skill there.
global_metadata() {
  printf '%s/skills/.metadata.json\n' "$(skillshare_home)"
}
