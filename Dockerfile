FROM operable/elixir:1.3.4-r0

# Select mix environment to use. We declare the MIX_ENV at build time
ARG MIX_ENV
ENV MIX_ENV ${MIX_ENV:-dev}

# Install runtime dependencies & nice-to-have packages
RUN apk update -U && apk add curl postgresql-client

# Setup Operable user. UID/GID default to 60000 but can be overriden.
ARG OPERABLE_UID
ENV OPERABLE_UID ${OPERABLE_UID:-60000}

ARG OPERABLE_GID
ENV OPERABLE_GID ${OPERABLE_UID:-60000}

RUN addgroup -g $OPERABLE_GID operable && \
    adduser -h /home/operable -D -u $OPERABLE_UID -G operable -s /bin/ash operable

# Create directories and upload cog source
WORKDIR /home/operable/cog
COPY . /home/operable/cog/
RUN chown -R operable /home/operable

RUN apk update -U && \
    apk add expat-dev gcc g++ libstdc++ make && \
    mix clean && mix deps.get && mix compile && \
    apk del gcc g++ && \
    rm -f /var/cache/apk/*

# This should be in place in the build environment already
COPY cogctl-for-docker-build /usr/local/bin/cogctl

USER operable
