# Jump to any repo under ~/Developer:  dev <part-of-name>   (no arg = list all)
dev() {
  local root="$HOME/Developer" hits
  if [ -z "$1" ]; then
    find "$root" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | sed "s#$root/##" | sort
    return
  fi
  hits=("${(@f)$(find "$root" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | cat | grep -i -- "$1")}")
  hits=("${(@)hits:#}")
  case ${#hits[@]} in
    0) echo "dev: no repo matches '$1'" >&2; return 1 ;;
    1) cd "${hits[1]}" ;;
    *) printf '%s\n' "${hits[@]#$root/}" >&2; echo "dev: ${#hits[@]} matches — be more specific" >&2; return 1 ;;
  esac
}
