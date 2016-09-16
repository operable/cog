FROM alpine:3.4

# Setup Operable APK repository
COPY config/docker/operable-56f35cdd.rsa.pub /etc/apk/keys/operable-56f35cdd.rsa.pub
RUN echo "@operable https://storage.googleapis.com/operable-apk/" > /etc/apk/repositories.operable && \
    cat /etc/apk/repositories >> /etc/apk/repositories.operable && \
    mv /etc/apk/repositories.operable /etc/apk/repositories

# Select mix environment to use. We declare the MIX_ENV at build time
ARG MIX_ENV
ENV MIX_ENV ${MIX_ENV:-dev}

# Install runtime dependencies & nice-to-have packages
RUN apk update -U && apk add bash ca-certificates curl git openssl postgresql-client

# Install Erlang
RUN apk update -U && \
    apk add `apk search erlang | grep -E "cos|eldap|gs|mibs|snmp|common-test|jinterface|megaco|diameter|odbc|observer|orber|test-server" -v | sed "s/-18.3.2-r0//g"`

# Install Elixir 1.3.1
RUN wget https://github.com/elixir-lang/elixir/releases/download/v1.3.1/Precompiled.zip && \
    unzip -d /usr/local Precompiled.zip && rm -f /usr/local/bin/*.bat && rm -f Precompiled.zip

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
