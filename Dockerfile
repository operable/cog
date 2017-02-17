FROM operable/elixir:1.3.4-r0

ENV MIX_ENV prod

RUN addgroup -g 60000 operable && \
    adduser -h /home/operable -D -u 60000 -G operable -s /bin/ash operable

# Create directories and upload cog source
WORKDIR /home/operable/cog
# Really, we only need the cog directory to be owned by operable,
# because (by default) that's where we write log files. None of the
# actual scripts or library files need to be owned by operable.
RUN chown -R operable /home/operable/cog
COPY . /home/operable/cog/

RUN apk --no-cache add expat-dev gcc g++ libstdc++ && \
    mix deps.get && mix compile && \
    apk del gcc g++

# This should be in place in the build environment already
COPY cogctl-for-docker-build /usr/local/bin/cogctl

USER operable
# TODO: For some reason, Hex needs to be present in the operable
# user's home directory for Cog to run (specifically, for it to apply
# the database migrations at startup). It complains of not being able
# to build gen_stage, *even though it's already been built!*
RUN mix local.hex --force
