#!/bin/sh

LOOPBACK=127.0.0.1
LOCALHOST=localhost
API_HOST=${COG_API_URL_HOST}
API_PORT=${COG_API_URL_PORT}
TRIGGER_HOST=${COG_TRIGGER_URL_HOST}
TRIGGER_PORT=${COG_TRIGGER_URL_PORT}
SERVICE_HOST=${COG_SERVICE_URL_HOST}
SERVICE_PORT=${COG_SERVICE_URL_PORT}

exit_with_err()
{
  echo "Errors occured during the health check. If using the default docker-compose file from Operable, make sure COG_HOST is set correctly." 1>&2
  echo "healthcheck.sh: $@" 1>&2
  exit 1
}

is_loopback()
{
  [ $@ == $LOOPBACK -o $@ == $LOCALHOST ]
  return $?
}

# First check to see if any endpoints are set to the loopback address or localhost
for host in $API_HOST $TRIGGER_HOST $SERVICE_HOST
do
  if is_loopback $host
  then
    exit_with_err "Can't use $LOOPBACK or $LOCALHOST for COG_API_URL_HOST, COG_TRIGGER_URL_HOST or COG_SERVICE_URL_HOST."
  fi
done


# Then check to make sure we can hit all endpoints
if ! nc -z $API_HOST $API_PORT
then
  exit_with_err "Cog API unavailable on $API_HOST:$API_PORT."
fi

if ! nc -z $TRIGGER_HOST $TRIGGER_PORT
then
  exit_with_err "Cog Trigger API unavailable on $TRIGGER_HOST:$TRIGGER_PORT."
fi

if ! nc -z $SERVICE_HOST $SERVICE_PORT
then
  exit_with_err "Cog Service API unavailable on $SERVICE_HOST:$SERVICE_PORT."
fi

exit 0
