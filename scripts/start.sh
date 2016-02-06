#!/bin/bash

MYNAME=`basename $0`

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

function usage {
  printf "%s [help|--help|-h|-?] <install_dir> \n" ${MYNAME}
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


# Set Cog and Relay environment variables if file exists
if [ -e "${HOME}/cog.vars" ]; then
  echo "Loading environemnt variables from ${HOME}/cog.vars."
  source "${HOME}/cog.vars"
fi

# Verify Cog and Relay environment variables have been set
function verify_env_vars {
  env_var=`/usr/bin/env | grep $1 | cut -d '=' -f 2`
  if [ -z ${env_var} ] ; then
    return 0
  else
    return 1
  fi
}

function verify_hipchat_vars {
  verify=1
  verify_env_vars "HIPCHAT_XMPP_JID"
  if [ $? == 0 ] ; then
    echo -e "\tERROR! HIPCHAT_XMPP_JID environment variable is not set."
    verify=$((verify&0))
  fi
  verify_env_vars "HIPCHAT_XMPP_PASSWORD"
  if [ $? == 0 ] ; then
    echo -e "\tERROR! HIPCHAT_XMPP_PASSWORD environment variable is not set."
    verify=$((verify&0))
  fi
  verify_env_vars "HIPCHAT_XMPP_SERVER"
  if [ $? == 0 ] ; then
    echo -e "\tERROR! HIPCHAT_XMPP_SERVER environment variable is not set."
    verify=$((verify&0))
  fi
  verify_env_vars "HIPCHAT_XMPP_ROOMS"
  if [ $? == 0 ] ; then
    echo -e "\tERROR! HIPCHAT_XMPP_ROOMS environment variable is not set."
    verify=$((verify&0))
  fi
  verify_env_vars "HIPCHAT_API_TOKEN"
  if [ $? == 0 ] ; then
    echo -e "\tERROR! HIPCHAT_API_TOKEN environment variable is not set."
    verify=$((verify&0))
  fi
  verify_env_vars "HIPCHAT_MENTION_NAME"
  if [ $? == 0 ] ; then
    echo -e "\tERROR! HIPCHAT_MENTION_NAME environment variable is not set."
    verify=$((verify&0))
  fi
  return ${verify}
}

function verify_cog_env {
  verify=1
  verify_env_vars "DATABASE_URL"
  if [ $? == 0 ] ; then
    echo -e "\tERROR! DATABASE_URL environment variable is not set."
  fi

  adapter_var=`/usr/bin/env | grep "COG_ADAPTER" | cut -d '=' -f 2`
  case ${adapter_var} in
    "")
      verify_env_vars "SLACK_API_TOKEN"
      if [ $? == 0 ] ; then
        echo -e "\tERROR! SLACK_API_TOKEN environment variable is not set. (COG_ADAPTER is not set and assumes a Slack adapter.)"
        verify=$((verify&0))
      fi
      ;;
    "Cog.Adapters.Slack")
      verify_env_vars "SLACK_API_TOKEN"
      if [ $? == 0 ] ; then
        echo -e "\tERROR! SLACK_API_TOKEN environment variable is not set."
        verify=$((verify&0))
      fi
      ;;
    "Cog.Adapters.HipChat")
      if ! verify_hipchat_vars ; then
        verify=$((verify&0))
      fi
      ;;
    *)
      echo -e "\tERROR! COG_ADAPTER is set to an unknown Cog Adapter. (Try 'Cog.Adapters.Slack' or 'Cog.Adapers.HipChat'.)"
      verify=$((verify&0))
      ;;
  esac
  shift
  return ${verify}
}

function start_cog {
  cd "${install_dir}/cog"
  #elixir --detached -e "File.write! '/var/run/cog.pid', :os.getpid" -S mix phoenix.server
  if [ ! -e "/var/run/operable" ]; then
    sudo -H mkdir /var/run/operable
    username=`/usr/bin/whoami`
    echo ${username}
    sudo -H chmod 775 /var/run/operable
    sudo -H /usr/sbin/chown -R ${username} /var/run/operable
  fi
  elixir --detached -e "File.write! '/var/run/operable/cog.pid', :os.getpid" -S mix phoenix.server
}


# Verify Cog has been installed with correct env vars set
if [ -e "${install_dir}/cog" ]; then
  echo "Cog installation detected at ${install_dir}/cog. Verifying required environment variables..."
  verify_cog_env
  if [ $? == 0 ] ; then
      echo "Please correct the above errors and try starting Cog again..."
      exit 1
  else
      echo "Cog environment variables verified."
      echo "Starting Cog..."
      start_cog
      cog_success=1
  fi
fi
