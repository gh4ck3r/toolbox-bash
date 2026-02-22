#!/bin/bash
#
# NAME:
#    parseargs.sh
#
# SYNOPSIS:
#    source parseargs.sh
#
# DESCRIPTION:
#    source this file and use parseargs() function while variable ARGV is defined
#    as associative array. It'll be filled with parsed arguments.
#
# DEPENDENCIES:
#    awk(1) - pattern scanning and processing language
#    getopt(1) - parse command options (enhanced)
#
# EXAMPLES:
#    In bash script following parse arguments and options as described its
#    preamble comment section.
#       source parseargs.sh
#       declare -A ARGV
#       parseargs "$@"
#    It can also be used for function, check function foo.bar defined below of
#    this script for more detail.
#
# AUTHOR:
#    Changbin Park <gh4ck3r@gmail.com>

function parseargs {
  err() { echo -e "\e[0;31m" "$@" "\e[0m" >&2; }

  if [[ ${ARGV@a} != *A* ]]; then
    local cmd; read _ cmd _ <<<$(caller 0)
    err "$cmd: variable ARGV should be defined as associative array"
    return 22
  fi
  set -u
  trap 'set +u' RETURN

  read _ ARGV[0] _ <<<$(caller 0)
  local line file
  if [[ ${ARGV[0]} == main ]]; then
    file=${BASH_SOURCE[1]}
    line=$(awk '/^\s*#/ {next} {exit} END{print NR}' $file)
  else
    read _ line file <<<$(shopt -s extdebug; declare -F ${ARGV[0]})
  fi

  local option_string=$(head -n $((line-1)) "$file" |
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
      match($0, /\s*--(\w{2,})(|=(\w+))\>/, m) {
        printf "%s%s%s,", m[1], (m[3] ? ":" : ""), m[3]
        found=1
      }
      found {found=0;print""}')

  local -A OPTKEYS;
  local option soptions="" loptions=""
  while read -d, option; do
    local opt val
    IFS=: read opt val <<<${option}
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
  while read option; do
    if [[ $option = ?,*, ]]; then
      local s l
      # parse same short/long option "c,optc,"
      IFS=, read s l <<<${option}
      OPTKEYS[-$s]=${OPTKEYS[--$l]}
    fi
  done <<<"${option_string}"

  soptions=${soptions%,}
  loptions=${loptions%,}
  eval set -- "$(getopt --name "${ARGV[0]}" \
    --longoptions "${loptions}" \
    --options "${soptions}" \
    -- "$@")"

  while :; do
    if [[ $1 == -- ]]; then
      shift; break;
    elif [[ -v OPTKEYS[$1:] ]]; then
      ARGV[${OPTKEYS[$1:]}]=$2;
      shift;
    elif [[ -v OPTKEYS[$1] ]]; then
      ARGV[${OPTKEYS[$1]}]=set;
    else
      err "${ARGV[0]}: unhandled option: '$1'"
    fi
    shift;
  done

  let i=1;
  for ((i=1;i<=$#;++i)); do
    ARGV[$i]=${!i}
  done
}

[[ -n $(caller 0) ]] && return
# not sourced from now on

function error() { echo -e "\e[0;31m" "$@" "\e[0m" >&2; }

################################################################################
# Description
#  This is a test function to invoke parseargs()
#
# Options
#   -a AVAL, --opta=AVAL  Description of opta
#   -b BVAL, --optb=BVAL
#     Description of optb. Sometimes description can be longer than others so it
#     starts next line.
#   -c, --optc            short and long set option
#   -d                    short set option only
#   -D DVAL               short value option only
#   --long                long set option only
#   --LONG=LONGVAL        long value option only
#
# Etc
#  Some additional sections may be following like this. And, it could be write
#  options that is similar to format of description of Options section like this
#  -x should be excluded from option processing
#  --XX should be excluded too
function foo.bar {
  local -A ARGV; parseargs "$@"

  set -e
  [[ ${ARGV[0]} == $FUNCNAME ]]
  [[ ${ARGV[1]} == "Hello world" ]]
  [[ ${ARGV[2]} == arg2 ]]
  [[ ${ARGV[3]} == arg3 ]]

  [[ ${ARGV[AVAL]} == hello2 ]]
  [[ ${ARGV[BVAL]} == world ]]
  [[ -v ARGV[optc] ]]
  [[ ${ARGV[DVAL]} == delta ]]
  [[ -v ARGV[long] ]]
  set +e
  echo "foo.bar() test PASS"
}
foo.bar -a hello1 --opta hello2 -b world -c -D delta --long "Hello world" arg2 arg3

