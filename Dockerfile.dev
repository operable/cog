FROM elixir:1.3-slim

# ENV MIX_ENV prod

RUN addgroup --gid 60000 cogbot && \
    adduser --home /home/cogbot --uid 60000 --gid 60000 --gecos cogbot \
        --shell /bin/bash --disabled-password cogbot

# Create directories and upload cog source
WORKDIR /home/cogbot/cog
# Really, we only need the cog directory to be owned by cogbot,
# because (by default) that's where we write log files. None of the
# actual scripts or library files need to be owned by cogbot.
RUN chown -R cogbot /home/cogbot/cog

RUN apt-get update && \
    apt-get -yqq install build-essential git libexpat1-dev && \
    rm -rf /var/lib/apt/lists/* && \
    mix do local.hex --force, local.rebar --force

COPY mix.exs mix.lock /home/cogbot/cog/
COPY config/ /home/cogbot/cog/config/

RUN mix do deps.get --no-archives-check, deps.compile

COPY . /home/cogbot/cog

RUN mix compile --no-deps-check --no-archives-check

# This should be in place in the build environment already
COPY cogctl-for-docker-build /usr/local/bin/cogctl

USER cogbot
# TODO: For some reason, Hex needs to be present in the cogbot
# user's home directory for Cog to run (specifically, for it to apply
# the database migrations at startup). It complains of not being able
# to build gen_stage, *even though it's already been built!*
RUN mix local.hex --force
