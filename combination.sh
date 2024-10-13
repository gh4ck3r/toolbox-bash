#!/bin/bash

function combo-invoker
{
  : ${1?callback}; [[ -z $(type -t $1) ]] && return 22
  local -r callback=$1; shift

  local -i n
  for((n=1; n < 2**$#; n++)); do
    local -a c=(); local e; local -i k=n
    for e in "${@}"; do
      (( k % 2 )) && c+=("$e")
      (( k>>=1 )) || break;
    done
    $callback "${c[@]}"
  done
}

function combo-env-invoker
{
  if [[ $# == 1 ]]; then $1; return; fi

  local -r var=$1
  local -rn arr=$1
  shift;

  local val
  for val in ${arr[@]:-""}; do
    [[ -n $val ]] && local $var=$val
    $FUNCNAME $@
  done
}

# "sourced script" ends here
return 0 2>/dev/null

########################################
false && ( # test combo-invoker {{{
function handler
{
  echo -n "$FUNCNAME: # args: $# --> "

  local -i i=0;
  local -a a;
  for a in "${@}"; do
    echo -n "$((++i)): [$a], "
  done
  echo
}

declare -a args=(a b c "1 2")
combo-invoker handler "${args[@]}"
) # }}}
########################################

########################################
false && ( # test combo-env-invoker {{{
declare -a ARGS=(
  FOO
  BAR
  BAZ
)

function env-dump
{
  for name in ${ARGS[@]}; do
    local -n var=$name
    echo -n "$name: ${var}, "
  done
  echo
}

declare -a FOO=(a b)
declare -a BAR=(1 2)
declare -a BAZ=(A B)
combo-env-invoker ${ARGS[@]} env-dump
) # }}}
########################################
