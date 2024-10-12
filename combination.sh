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

# "sourced script" ends here
return 0 2>/dev/null

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
