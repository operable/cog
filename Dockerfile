FROM debian:jessie

ENV DEBIAN_FRONTEND noninteractive

# Set locale
ENV LANG C.UTF-8
ENV LANGUAGE C.UTF-8
ENV LC_ALL C.UTF-8

RUN apt-get update -qq && apt-get install -y locales -qq && locale-gen en_US.UTF-8 en_us && dpkg-reconfigure locales && dpkg-reconfigure locales && locale-gen C.UTF-8 && /usr/sbin/update-locale LANG=C.UTF-8

# Add some basic dependencies
RUN apt-get install -y apt-transport-https build-essential git-core postgresql-client unzip wget

# Setup Elixir runtime
RUN echo "deb https://packages.erlang-solutions.com/debian jessie contrib" >> /etc/apt/sources.list && \
    apt-key adv --fetch-keys http://packages.erlang-solutions.com/debian/erlang_solutions.asc && \
    apt-get -qq update && apt-get install -y esl-erlang=1:18.1 && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Download and Install Specific Version of Elixir
WORKDIR /elixir
RUN wget -q https://github.com/elixir-lang/elixir/releases/download/v1.1.1/Precompiled.zip && \
    unzip Precompiled.zip && \
    rm -f Precompiled.zip && \
    ln -s /elixir/bin/elixirc /usr/local/bin/elixirc && \
    ln -s /elixir/bin/elixir /usr/local/bin/elixir && \
    ln -s /elixir/bin/mix /usr/local/bin/mix && \
    ln -s /elixir/bin/iex /usr/local/bin/iex

# Install local Elixir hex and rebar
RUN /usr/local/bin/mix local.hex --force && \
    /usr/local/bin/mix local.rebar --force

WORKDIR /

# Setup Cog
ENV MIX_ENV staging
RUN mkdir -p /app
WORKDIR /app

COPY mix.exs mix.lock /app/
RUN mix deps.get && mix deps.compile

COPY . /app/

RUN mix clean && mix compile
RUN rm -f /app/.dockerignore
