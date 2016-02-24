FROM operable/docker-base

# Setup Mix Environment to use. We declare the MIX_ENV at build time
ARG MIX_ENV
ENV MIX_ENV ${MIX_ENV:-dev}

# Setup Cog
RUN mkdir /home/operable/cog \
          /home/operable/cog/config
WORKDIR /home/operable/cog

COPY mix.exs mix.lock /home/operable/cog/
COPY config/helpers.exs /home/operable/cog/config/
RUN mix deps.get && mix deps.compile

COPY . /home/operable/cog/
RUN mix clean && mix compile
RUN rm -f /home/operable/cog/.dockerignore

# Setup cogctl
RUN mkdir /home/operable/cogctl
RUN cd /home/operable/cogctl && \
    git clone https://github.com/operable/cogctl . && \
    mix escript
