ARG ELIXIR_VERSION=1.18.4
ARG OTP_VERSION=27.3.4.1
ARG DEBIAN_CODENAME=trixie

FROM hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_CODENAME}-20260223

# Install dev dependencies
# nodejs/npm needed for JS packages used by esbuild (see assets/package.json),
# matching the production Dockerfile.
RUN apt-get update -y && \
    apt-get install -y build-essential git inotify-tools curl nodejs npm && \
    apt-get clean && rm -f /var/lib/apt/lists/*_*

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Create vscode user
RUN groupadd --gid 1000 vscode && \
    useradd --uid 1000 --gid 1000 -m vscode

USER vscode
