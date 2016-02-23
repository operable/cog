FROM operable/docker-base

# Setup Mix Environment to use. We declare the MIX_ENV at build time
ARG MIX_ENV
ENV MIX_ENV ${MIX_ENV:-dev}

# Setup Cog
COPY mix.exs mix.lock /home/operable/
RUN mkdir /home/operable/config
COPY config/helpers.exs /home/operable/config/
RUN mix deps.get && mix deps.compile

COPY . /home/operable/

RUN mix clean && mix compile
RUN rm -f /home/operable/.dockerignore
