#!/bin/bash

function isarray
{
  [[ $(declare -p $1 2>/dev/null) = "declare -a"* ]]
}

function arr-dump
{
  : ${1?name of array}
  declare -n var=$1
  local k
  for k in ${!var[@]}; do
    echo -e "$1[$k]: ${var[$k]}"
  done
}

function arr-sort
{
  : ${1?name of array}
  isarray $1 || return 22
  declare -n var=$1

  local _IFS=$IFS
  IFS=$'\n' var=($(sort -n <<<${var[*]}))
  IFS=_IFS
}

# "sourced script" ends here
return 0 2>/dev/null

declare unsorted_arr=(4 2 3 1)
echo "===================="
echo "arr-dump unsorted_arr"
echo --------------------
arr-dump unsorted_arr
echo "===================="
echo arr-sort unsorted_arr
arr-sort unsorted_arr
echo "===================="
echo "arr-dump unsorted_arr"
echo --------------------
arr-dump unsorted_arr
echo ====================
