#!/usr/bin/env bash

set -euo pipefail

HOST=postgres
PORT=5432

# 90x2 = 180 seconds = 3 minutes total wait time
TIMES=90 # Number of times to test if Cog is up
SLEEP=2 # Time to wait between tries (seconds)
REMAINING=${TIMES}

while true
do
    if [ $REMAINING -eq 0 ]
    then
        echo "Postgres hasn't come up after $(( ${SLEEP}*${TIMES} )) seconds; aborting"
        exit 1
    fi

    sleep $SLEEP

    if nc -z $HOST $PORT
    then
        echo "Postgres is up at ${HOST}:${PORT}"
        break
    else
        REMAINING=$(( ${REMAINING}-1 ))
        echo "Postgres is not up yet (${REMAINING} tries remaining)"
        continue
    fi
done
