#!/bin/bash

# Pretty ANSI output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
MYNAME=`basename $0`

COG_REPO="git@github.com:operable/cog"
RELAY_REPO="git@github.com:operable/relay"

# All the executables needed to clone and
# build Cog & Relay
erl_path=""
iex_path=""
mix_path=""
make_path=""
git_path=""

install_dir=""
verbose="0"

# Clean up when we're done. For now this means
# restoring the user's working directory.
function finish {
  popd >& /dev/null
}

trap finish EXIT

# Push current working directory onto stack so
# we can return here when we're done.
pushd >& /dev/null

function write_log {
  local fmtstr=$1
  shift
  printf "${GREEN}${fmtstr}${NC}\n" $@
}

function write_err {
  local fmtstr=$1
  shift
  printf "${RED}${fmtstr}${NC}\n" $@ 1>&2
}

function write_check {
  local fmtstr=$1
  shift
  printf "${fmtstr}....." $@
}

function write_check_result {
  if [ "$#" == "0" ] || [ "$1" == "" ]; then
    printf "${RED}Not found${NC}\n"
  else
    if [ "$1" == "No" ]; then
      printf "${RED}%s${NC}\n" $1
    else
      printf "${GREEN}%s${NC}\n" $1
    fi
  fi
}

function abort {
  write_err "Setup aborted."
  exit 1
}

function have_command {
  local cmd=$1
  local cmd_path=`which ${cmd}`
  if [ "${cmd_path}" == "" ]; then
    echo ""
  else
    echo ${cmd_path}
  fi
}

function bail_on_missing_commands {
  if [ -z "${erl_path}" ] || [ -z "${iex_path}" ] || [ -z "${mix_path}" ] ||
     [ -z "${make_path}" ] || [ -z "${git_path}" ]; then
  abort
fi
}

function dirty_scheduler_check {
  if ! ERL_CRASH_DUMP=/dev/null ${erl_path} -noshell -eval "erlang:system_info(dirty_cpu_schedulers)." -eval "init:stop()" > /dev/null 2>&1 ; then
    return 1
  else
    return 0
  fi
}

function usage {
  printf "%s [help|--help|-h|-?|--verbose|-v] <install_dir> \n" ${MYNAME}
}

while [ "$#" -gt 0 ];
do
  case "$1" in
    help)
      usage && exit 0
      ;;
    \?)
      usage && exit 0
      ;;
    -\?)
      usage && exit 0
      ;;
    --help)
      usage && exit 0
      ;;
    -h)
      usage && exit 0
      ;;
    --verbose)
      verbose="1"
      ;;
    -v)
      verbose="1"
      ;;
    *)
      install_dir="$1"
      ;;
  esac
  shift
done

# Set install dir to current directory if one wasn't set.
if [ "$install_dir" == "" ]; then
  install_dir=`pwd`
fi

# Ensure we have all required commands installed
write_check "Erlang installed"
erl_path=`have_command erl`
write_check_result ${erl_path}
write_check "Elixir installed"
iex_path=`have_command iex`
write_check_result ${iex_path}
write_check "Mix installed"
mix_path=`have_command mix`
write_check_result ${mix_path}
write_check "Make installed"
make_path=`have_command make`
write_check_result ${make_path}
write_check "Git installed"
git_path=`have_command git`
write_check_result ${git_path}


# Bail if not
bail_on_missing_commands

# Ensure detected Erlang has dirty scheduler support
write_check "Erlang dirty CPU schedulers supported"
if ! dirty_scheduler_check ; then
  write_check_result "No"
  write_err "Detected Erlang '%s' lacks required dirty scheduler support." ${erl_path}
  write_err "See http://erlang.org/doc/installation_guide/INSTALL.html for more information."
  abort
else
  write_check_result "Yes"
fi
write_log "Prequisite checks completed."
write_log

if ! mkdir -p ${install_dir} ; then
  write_err "Error preparing installation directory."
  abort
fi

cd ${install_dir}

write_log "Cloning Cog and Relay repos."

if [ ! -d cog ]; then
  if ! ${git_path} clone ${COG_REPO} ; then
    write_err "Error cloning ${COG_REPO} to ${install_dir}/cog"
    abort
  fi
else
  write_log "Updating previous Cog clone."
  cd cog && ${git_path} pull
  cd ..
fi

if [ ! -d relay ]; then
  if ! ${git_path} clone ${RELAY_REPO} ; then
    write err "Error cloning ${RELAY_REPO} to ${install_dir}/relay"
    abort
  fi
else
  write_log "Updating previous Relay clone."
  cd relay && ${git_path} pull
  cd ..
fi

write_log "Building Cog."
cd cog

if [ "${verbose}" == "0" ]; then
  ${make_path} setup >& /dev/null
else
  ${make_path} setup
fi
if [ "$?" != "0" ]; then
  write_err "Cog build failed."
  abort
else
  write_log "Cog build completed."
fi

write_log "Building Relay."
cd ../relay

if [ "${verbose}" == "0" ]; then
  ${mix_path} deps.get >& /dev/null
else
  ${mix_path} deps.get
fi
if [ "$?" != "0" ]; then
  write_err "Relay build failed."
  abort
fi

if [ "${verbose}" == "0" ]; then
  ${mix_path} compile >& /dev/null
else
  ${mix_path} compile
fi
if [ "$?" != "0" ]; then
  write_err "Relay build failed."
  abort
fi
write_log "Relay build completed."

cd ${install_dir}

write_log

write_log "To start Cog:\tcd %s/cog && make run" ${install_dir}
write_log "To start Relay:\tcd %s/relay && scripts/start.sh" ${install_dir}
