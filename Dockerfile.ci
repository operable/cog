FROM operable/elixir:1.3.4-r0

# Greenbar-only compilation dependencies
RUN apk -U add expat-dev gcc g++ libstdc++

COPY mix.exs mix.lock /code/
COPY config/ /code/config/
WORKDIR /code
RUN mix deps.get
RUN MIX_ENV=test mix deps.compile

COPY emqttd_plugins/ /code/emqttd_plugins/
COPY priv/ /code/priv/
COPY test/ /code/test/
COPY web/ /code/web/
COPY lib/ /code/lib/

RUN MIX_ENV=test mix compile

COPY .buildkite/ /code/.buildkite
COPY scripts/ /code/scripts/
COPY Makefile /code
