#!/bin/bash
#
# NAME:
#    parseargs.sh - argument parser as described in preamble
#
# SYNOPSIS:
#   source parseargs.sh
#
# DESCRIPTION:
#   source this file whenever you need to parse arguments of script or
#   function. Once sourced this file there will be only positional arguments
#   left and all options will be stored in environment variable OPTIONS. It can
#   be sourced from both script scope and function scope repeatedly.
#   Environment variables ARGV and OPTIONS is defined as indexed array and
#   associative array respectively. ARGV contains positional arguments and
#   OPTIONS contains options parsed from arguments as described in the preamble,
#   which refers to the comment block located at the beginning of a script or
#   immediately above a function definition.
#
# DEPENDENCIES:
#   awk(1) - pattern scanning and processing language
#   getopt(1) - parse command options (enhanced)
#
# EXAMPLES:
#   source parseargs.sh
#   for opt in "${!OPTIONS[@]}"
#   do
#     echo "  - $opt: ${OPTIONS[$opt]}"
#   done
#   for ((i=0;i <= $#; i++))
#   do
#     echo "[$i]: ${!i}"
#   done
#
# SIDE EFFECTS:
#   Environment variables ARGV and OPTIONS is defined after sourced.
#
# AUTHOR:
#    Changbin Park <gh4ck3r@gmail.com>

if [[ -z $(caller 0) ]]; then
  echo -e "\e[0;31m${BASH_SOURCE[0]##/*} is meant to be sourced\e[0m" >&2;
  exit 1
fi

[[ $(type -t err) = function ]] ||
function err() { echo -e "\e[0;31m" "$@" "\e[0m" >&2; }

[[ $(type -t parseargs) = function ]] ||
function parseargs {
  if [[ "${BASH_SOURCE[0]}" != "${BASH_SOURCE[1]}" ]]; then
    echo -e "\e[0;31m${BASH_SOURCE[0]##/*} is meant to be sourced\e[0m" >&2;
    exit 1
  fi

  local cmd;
  read -r _ cmd _ <<<"$(caller 0)"
  [[ $cmd == source ]] && read -r _ cmd _ <<<"$(caller 1)"
  local -r cmd

  if [[ ${ARGV@a} != *a* ]] || [[ ${OPTIONS@a} != *A* ]]; then
    if [[ $cmd = main ]]; then
      err "$cmd: variable ARGV and OPTIONS should be defined as indexed and associative array"
    else
      err "${BASH_SOURCE[1]##*/}: variable ARGV and OPTIONS should be defined as indexed and associative array"
    fi
    return 22
  fi
  local old_opts;
  old_opts=$(set +o | grep nounset); set -u; trap '$old_opts' RETURN

  local line file
  if [[ $cmd == main ]]; then
    file=${BASH_SOURCE[1]}
    [[ $file == "${BASH_SOURCE[0]}" ]] && file=${BASH_SOURCE[2]}
    line=$(unset POSIXLY_CORRECT; awk '/^\s*#/ {next} {exit} END{print NR}' "$file")
    ARGV[0]=${file##*/}
  else
    read -r _ line file <<<"$(shopt -s extdebug; declare -F "$cmd")"
    ARGV[0]=$cmd
  fi

  local option_string;
  option_string=$(unset POSIXLY_CORRECT; head -n $((line-1)) "$file" |
    tac | awk '
      $1 ~ /^#/ && $2 ~ /^O(ptions?|PTIONS?):?/ {print; exit}
      !NF || $1 != "#" {exit}
      {print}' |
    tac | awk '
      $1 ~ /^#/ && NF==1 {exit}
      match($0, /\s*-(\w)\>(| (\w+))\>/, m) {
        printf "%s%s%s,", m[1], (m[3] ? ":" : ""), m[3]
        found=1
      }
      match($0, /\s*--(\w{2,})(|[= ](\w+))\>/, m) {
        printf "%s%s%s,", m[1], (m[3] ? ":" : ""), m[3]
        found=1
      }
      found {found=0;print""}')
  local -r option_string;

  local -A OPTKEYS;
  #FIXME: determine whether soptions begin with + or not.
  local option soptions="+" loptions=""
  while read -rd, option; do
    local opt val
    IFS=: read -r opt val <<<"${option}"
    if ((${#opt}==1)); then
      soptions+=${opt}${val:+:},
      if [[ -v OPTKEYS[-${opt}${val:+:}] ]]; then
        err "${ARGV[0]}: duplicated option key for: ${opt}"
        return 126
      else
        OPTKEYS[-${opt}${val:+:}]=${val:-${opt}}
      fi
    else
      loptions+=${opt}${val:+:},
      if [[ -v OPTKEYS[--${opt}${val:+:}] ]]; then
        err "${ARGV[0]}: duplicated option key for: ${opt}"
        return 126
      else
        OPTKEYS[--${opt}${val:+:}]=${val:-${opt}}
      fi
    fi
  done <<<"${option_string}"
  while read -r option; do
    if [[ $option = ?,*, ]]; then
      local s l
      # parse same short/long option "c,optc,"
      IFS=, read -r s l <<<"${option}"
      OPTKEYS[-$s]=${OPTKEYS[--$l]}
    fi
  done <<<"${option_string}"

  [[ $1 == -- ]] && shift
  local opt
  if ! opt=$(getopt --name "${ARGV[0]}" \
    --options "${soptions%,}" \
    --longoptions "${loptions%,}" \
    -- "$@"); then return 1
  fi
  eval set -- "$opt"

  while :; do
    if [[ $1 == -- ]]; then
      shift; break;
    elif [[ -v OPTKEYS[$1:] ]]; then
      OPTIONS[${OPTKEYS[$1:]}]=$2;
      shift;
    elif [[ -v OPTKEYS[$1] ]]; then
      OPTIONS[${OPTKEYS[$1]}]="set";
    else
      err "${ARGV[0]}: unhandled option: '$1'"
    fi
    shift;
  done

  local -i i
  for ((i=1;i<=$#;++i)); do
    ARGV["$i"]=${!i}
  done
}

declare -a ARGV=()
declare -A OPTIONS=()
parseargs -- "$@"
set -- "${ARGV[@]:1}"

