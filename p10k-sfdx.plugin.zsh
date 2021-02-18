#   for i in {0..255}; do print -Pn "%K{$i}${(l:3::0:)i}%k " ${${(M)$((i%8)):#7}:+$'\n'}; done

_find_local_sfdx_config_file() {
  local dir="$1"
  while true; do
    _p9k__ret="${dir}/.sfdx/sfdx-config.json"
    [[ -s $_p9k__ret ]] && return 0
    [[ $dir == / ]] && return 1
    dir=${dir:h}
  done
}

_get_aliaseOrUsername() {
  [[ -s "$1" ]] || return 1
  _p9k__ret="$(jq -r '.defaultusername|strings' $1 2>/dev/null)"
  [[ -n "$_p9k__ret" ]] && return 0
  return 1
}

_get_userName() {
  [[ -n "$1" ]] || return 1
  [[ -s "$HOME/.sfdx/alias.json" ]] || return 1
  _p9k__ret="$(jq --arg aliaseOrUsername "$1" -r '.orgs[$aliaseOrUsername]|strings' $HOME/.sfdx/alias.json 2>/dev/null)"
  if [[ -n "$_p9k__ret" ]]; then
    return 0
  else
    _p9k__ret="$1"
    return 0
  fi
  return 1
}

_get_scratchOrgExpirationDate() {
  [[ -n "$1" ]] || return 1
  _p9k__ret=$(sfdx force:org:display --targetusername=$1 --json 2>&1 | jq -r 'if .status == 1 then "error" elif .result.status == "Active" then .result.expirationDate elif .result.status == "Expired" then "expired" else "sbx" end' 2>/dev/null)
  [[ -n "$_p9k__ret" ]] && return 0
  return 1
}

function prompt_sfdx() {
  if (( $+commands[jq] )) && (( $+commands[sfdx] )); then
    
    if _find_local_sfdx_config_file "${(%):-%/}"; then
      local sfdx_config_file=$_p9k__ret
    else
      return 0
    fi
    
    if _get_aliaseOrUsername "$sfdx_config_file"; then
      local aliaseOrUsername=$_p9k__ret
      local global=false
      elif _get_aliaseOrUsername "$HOME/.sfdx/sfdx-config.json"; then
      local aliaseOrUsername=$_p9k__ret
      local global=true
    else
      return 0
    fi
    
    if [[ "$global" = "true" ]] || [[ $sfdx_config_file -ef $HOME/.sfdx/sfdx-config.json ]]; then
      local state=GLOBAL
      local displayname="(global) $aliaseOrUsername"
    else
      local state=LOCAL
      local displayname="$aliaseOrUsername"
    fi
    
    if _get_userName "$aliaseOrUsername"; then
      local username=$_p9k__ret
      local authInfoFile="$HOME/.sfdx/$username.json"
    fi
    
    if [[ -s $authInfoFile ]]; then
      if ! _p9k_cache_stat_get $0 $authInfoFile; then
        if _get_scratchOrgExpirationDate "$aliaseOrUsername"; then
          local expirationDate=$_p9k__ret
          _p9k_cache_stat_set "$expirationDate"
        fi
      else
        [[ -n $_p9k__cache_val[1] ]] && local expirationDate=$_p9k__cache_val[1]
      fi
      case $expirationDate in
        error)
          local state=ERROR
          local displayname="$displayname (error)"
        ;;
        expired)
          local state=EXPIRED
          local displayname="$displayname (expired)"
        ;;
        sbx)
          local displayname="$displayname (SBX)"
        ;;
        *)
          if [[ -n $expirationDate ]]; then
            local date1=$(strftime -r '%F' $expirationDate)
            local date2=$(strftime -r '%F' $(date "+%Y-%m-%d"))
            ([[ -n "$date1" ]] && [[ -n "$date2" ]]) || break
            local diff=$(( $date1 - $date2 ))
            if (( $diff > 0)); then
              local lifetime=$(( $diff / 86400 ))
              local displayname="$displayname (${lifetime}d)"
            else
              local state=EXPIRED
              local displayname="$displayname (expired)"
            fi
          fi
        ;;
      esac
    else
      local state=ERROR
      local displayname="$displayname (error)"
    fi
    
    p10k segment -s $state -i $'\uf65e' -b 68 -f white -t "$displayname"
  fi
}

#
# adds a new segment $1 to the right prompt at position $2
#
(( $+functions[p9kaddSegmentToRightPromptAt] )) ||
function p9kaddSegmentToRightPromptAt() {
  local segment=$1
  local at=$2
  [[ -n "$segment" ]] || return 1
  [[ $at == <1-> ]] || return 1
  if (( ! POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS[(Ie)$segment] )); then
    typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS[$at,0]=$segment
    # If p10k is already loaded, reload configuration.
    # This works even with POWERLEVEL9K_DISABLE_HOT_RELOAD=true.
    (( ! $+functions[p10k] )) || p10k reload
    return 0
  fi
}

#
# gets the current powerlevel10k style
#
(( $+functions[p10kgetstyle] )) ||
function p10kgetstyle() {
  if [[ -f $POWERLEVEL9K_CONFIG_FILE ]]; then
    local lines=( "${(@f)"$(<$POWERLEVEL9K_CONFIG_FILE)"}" )
    if [[ ${(@M)lines:#(#b)*p10k-(*).zsh*} ]]; then
      echo $match[1]
    fi
  fi
}

p9kaddSegmentToRightPromptAt sfdx 18
case $(p10kgetstyle) in
  rainbow)
    POWERLEVEL9K_SFDX_LOCAL_BACKGROUND=38
    POWERLEVEL9K_SFDX_GLOBAL_BACKGROUND=208
    POWERLEVEL9K_SFDX_ERROR_BACKGROUND=97
    POWERLEVEL9K_SFDX_EXPIRED_BACKGROUND=102   
  ;;
  *)
    POWERLEVEL9K_SFDX_LOCAL_FOREGROUND=38  
    POWERLEVEL9K_SFDX_GLOBAL_FOREGROUND=208
    POWERLEVEL9K_SFDX_ERROR_FOREGROUND=97
    POWERLEVEL9K_SFDX_EXPIRED_FOREGROUND=102
  ;;
esac
POWERLEVEL9K_SFDX_SHOW_ON_COMMAND='sfdx'
