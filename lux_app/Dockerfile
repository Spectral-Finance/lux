FROM elixir:1.18-alpine AS build

# Install build dependencies
RUN apk add --no-cache build-base npm git python3

WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set build ENV
ENV MIX_ENV=prod

# Install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# Copy config files
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

# Build assets
COPY assets assets
COPY priv priv
RUN mix assets.deploy

# Build project
COPY lib lib
RUN mix compile

# Build release
COPY config/runtime.exs config/
RUN mix release

# Start a new build stage for the final image
FROM alpine:3.18 AS app

RUN apk add --no-cache libstdc++ openssl ncurses-libs

WORKDIR /app

RUN chown nobody:nobody /app

USER nobody:nobody

COPY --from=build --chown=nobody:nobody /app/_build/prod/rel/lux_app ./

ENV HOME=/app

CMD ["bin/lux_app", "start"] 