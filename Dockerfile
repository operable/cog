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
RUN mkdir -p /home/operable/cog /home/operable/cogctl
COPY . /home/operable/cog/
RUN chown -R operable /home/operable && \
    rm -f /home/operable/.dockerignore

# We do this all in one huge RUN command to get the smallest
# possible image.
USER root
RUN apk update -U && \
    apk add expat-dev gcc g++ libstdc++ make && \
    # build cog and cogctl \
    su operable - -c /home/operable/cog/scripts/docker-build && \
    # install cogctl and delete source directory \
    cp /home/operable/cogctl/cogctl /usr/local/bin/cogctl && \
    rm -rf /home/operable/cogctl && \
    # cleanup dependencies
    apk del gcc g++ && \
    rm -f /var/cache/apk/*

USER operable
WORKDIR /home/operable/cog
