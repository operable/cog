#!/bin/bash

MYNAME=`basename $0`
install_dir=""

# Clean up when we're done. For now this means
# restoring the user's working directory.
function finish {
  popd >& /dev/null
}

trap finish EXIT

# Push current working directory onto stack so
# we can return here when we're done.
pushd >& /dev/null

function usage {
  printf "%s [help|--help|-h|-?] <install_dir> \n" ${MYNAME}
  exit 0
}

while [ "$#" -gt 0 ];
do
  case "$1" in
    help)
      usage
      ;;
    \?)
      usage
      ;;
    -\?)
      usage
      ;;
    --help)
      usage
      ;;
    -h)
      usage
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


# Set Cog environment variables if file exists
if [ -e "${HOME}/cog.vars" ]; then
  echo "Loading environemnt variables from ${HOME}/cog.vars."
  source "${HOME}/cog.vars"
fi

# Verify Cog environment variables have been set
function verify_env_vars {
  env_var=`/usr/bin/env | grep $1 | cut -d '=' -f 2`
  if [ -z ${env_var} ] ; then
    return 1
  else
    return 0
  fi
}

function verify_slack_vars {
  verify=0
  if ! verify_env_vars "SLACK_API_TOKEN" ; then
    echo -e "\tERROR! SLACK_API_TOKEN environment variable is not set."
    verify=$((verify+1))
  fi
  return ${verify}
}

function verify_cog_env {
  verify=0
  if ! verify_env_vars "DATABASE_URL" ; then
    echo -e "\tERROR! DATABASE_URL environment variable is not set."
  fi

  adapter_var=`/usr/bin/env | grep "COG_ADAPTER" | cut -d '=' -f 2`
  case ${adapter_var} in
    "")
      echo -e "\tWarning: COG_ADAPTER environment variable is not set; using Slack as the default adapter"
      if ! verify_env_vars "SLACK_API_TOKEN" ; then
        echo -e "\tERROR! SLACK_API_TOKEN environment variable is not set. (COG_ADAPTER is not set and assumes a Slack adapter.)"
        verify=$((verify+1))
      fi
      ;;
    "Slack")
      if ! verify_slack_vars ; then
        verify=$((verify+1))
      fi
      ;;
    *)
      echo -e "\tERROR! COG_ADAPTER is set to an unknown Cog Adapter. (Try 'Slack'.)"
      verify=$((verify+1))
      ;;
  esac
  shift
  return ${verify}
}

function start_cog {
  cd "${install_dir}/cog"
  if [ ! -e "/var/run/operable" ]; then
    # Do not attempt to setup the directory, just error
    echo -e "\tERROR! '/var/run/operable' does not exist. Please be sure permissions are correct."
  fi
  elixir --detached -e "File.write! '/var/run/operable/cog.pid', :os.getpid" -S mix phoenix.server
}


# Verify Cog has been installed with correct env vars set
if [ -e "${install_dir}/cog" ]; then
  echo "Cog installation detected at ${install_dir}/cog. Verifying required environment variables..."
  if ! verify_cog_env ; then
    echo "Please correct the above errors and try starting Cog again..."
    exit 1
  else
    echo "Cog environment variables verified."
    echo "Starting Cog..."
    start_cog
    echo "Welcome operatives to the World of Cog."
  fi
fi
