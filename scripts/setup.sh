#!/bin/bash

# Pretty ANSI output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
MYNAME=`basename $0`
MYFULLNAME=$( cd $(dirname $0) ; pwd -P )/${MYNAME}
MYCHECKSUM=`shasum ${MYFULLNAME} | cut -f1 -d' '`
RELEASE_TAG="0.2"

REPOS="cog relay cogctl relayctl"
COG_REPO="git@github.com:operable/cog"
RELAY_REPO="git@github.com:operable/relay"
COGCTL_REPO="git@github.com:operable/cogctl"
RELAYCTL_REPO="git@github.com:operable/relayctl"

# All the executables needed to clone and
# build Cog & Relay
erl_path=""
iex_path=""
mix_path=""
make_path=""
git_path=""

install_dir=""
verbose="0"

if [ -e "${HOME}/cog.vars" ]; then
  echo "Loading environemnt variables from ${HOME}/cog.vars."
  source "${HOME}/cog.vars"
fi

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

function restart_on_changes {
  checksum=`shasum $1 | cut -f1 -d' '`
  if [ "${checksum}" != "${MYCHECKSUM}" ]; then
    write_log "Changes to setup.sh detected. Restarting setup process."
    write_log
    exec $1
  fi
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
    --tag)
      shift
      RELEASE_TAG="$1"
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


write_log "Cloning repositories for the following projects: ${REPOS}\n"

for repo in ${REPOS}; do
  if [ ! -d $repo ]; then
    repo_var="$(echo ${repo} | tr '[:lower:]' '[:upper:]')_REPO"
    eval repo_var=\$${repo_var}
    if ! ${git_path} clone ${repo_var} ; then
      write_err "Error cloning ${repo_var} into ${repo}."
      abort
    else
      cd ${repo}
      if ! ${git_path} checkout ${RELEASE_TAG} ; then
        write_err "Error refreshing ${repo} to release tag ${RELEASE_TAG}"
        abort
      fi
      cd ..
    fi
  else
    write_log "Updating previous ${repo} clone."
    cd ${repo}
    if ! ( ${git_path} fetch -t && ${git_path} checkout ${RELEASE_TAG} ) ; then
      write_err "Error refreshing previous ${repo} clone to release tag ${RELEASE_TAG}"
      abort
    fi
    cd ..
  fi

  restart_on_changes ${MYFULLNAME}

  cd ${repo}

  write_log "Building ${repo}."
  case "${repo}" in
    cog)
      if [ "${verbose}" == "0" ]; then
        ${make_path} setup >& /dev/null
      else
        ${make_path} setup
      fi
      if [ "$?" != "0" ]; then
        write_err "${repo} build failed."
        abort
      else
        write_log "${repo} build completed."
      fi
      ;;
    relay)
      if [ "${verbose}" == "0" ]; then
        ${mix_path} deps.get >& /dev/null
      else
        ${mix_path} deps.get
      fi
      if [ "$?" != "0" ]; then
        write_err "Relay build failed."
        abort
      else
        write_log "${repo} build completed."
      fi
      ;;
    *)
      if [ "${verbose}" == "0" ]; then
        ${mix_path} escript >& /dev/null
      else
        ${mix_path} escript
      fi
      if [ "$?" != "0" ]; then
        write_err "${repo} build failed."
        abort
      else
        write_log "${repo} build completed."
      fi
      ;;
  esac

  cd ..
done

cd ${install_dir}

write_log
write_log "Cog is configured via environment variables. Make sure that"
write_log "these variables are configured before running the commands below."
write_log "If you are using the Cog AMI, you can find a default set of these"
write_log "in ${HOME}/cog.vars. Note that you will have to add configuration"
write_log "for your chat provider."
write_log

write_log "To start Cog:\tcd %s/cog && make run" ${install_dir}
write_log "To start Relay:\tcd %s/relay && scripts/relay start" ${install_dir}
write_log
write_log "Path to relayctl:\t%s/relayctl" ${install_dir}
write_log "Path to cogctl:\t%s/cogctl" ${install_dir}
write_log
write_log "We hope you enjoy using Cog!"

