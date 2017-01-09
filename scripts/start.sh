#!/bin/sh

CONFIG_PATH=sys.config

rm -f ${CONFIG_PATH}

COG_DB_USER=${USER} \
COG_DB_NAME=cog_dev \
deps/conform/priv/bin/conform --conf cog.conf --schema config/cog.schema.exs --filename ${CONFIG_PATH}

iex --erl "-config ${CONFIG_PATH}" -e "Application.start(:cog)"

