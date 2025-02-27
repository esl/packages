# -*- mode: dockerfile -*-
# syntax = docker/dockerfile:1.2
ARG image
FROM ${image} as builder
ARG os
ARG os_version

ENV DEBIAN_FRONTEND=noninteractive

# Setup ESL repo
RUN rm -f /etc/apt/apt.conf.d/docker-clean; echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache
RUN --mount=type=cache,id=${os}_${os_version},target=/var/cache/apt,sharing=private \
  --mount=type=cache,id=${os}_${os_version},target=/var/lib/apt,sharing=private \
  apt-get --quiet update && \
  apt-get --quiet --yes --no-install-recommends install \
  build-essential \
  ca-certificates \
  libsctp1 \
  procps \
  git \
  gnupg \
  wget

# Install Erlang/OTP
ARG erlang_version
RUN --mount=type=cache,id=${os}_${os_version},target=/var/cache/apt,sharing=private \
  --mount=type=cache,id=${os}_${os_version},target=/var/lib/apt,sharing=private \
  wget https://esl-erlang.s3.eu-west-2.amazonaws.com/${os}/${os_version}/esl-erlang_${erlang_version}-1~${os}~${os_version}_amd64.deb && \
  dpkg -i esl-erlang_${erlang_version}-1~${os}~${os_version}_amd64.deb

# Install FPM dependencies
RUN --mount=type=cache,id=${os}_${os_version},target=/var/cache/apt,sharing=private \
  --mount=type=cache,id=${os}_${os_version},target=/var/lib/apt,sharing=private \
  apt-get --quiet update && apt-get --quiet --yes --no-install-recommends install \
  gcc \
  make \
  $(apt-cache show libffi7 >/dev/null 2>&1; \
  libffi7 \
  curl \
  libssl-dev\
  openssl\
  libreadline-dev \
  zlib1g-dev

# Ruby version and fpm
RUN --mount=type=cache,id=${os}_${os_version},target=/var/cache/apt,sharing=private \
    --mount=type=cache,id=${os}_${os_version},target=/var/lib/apt,sharing=private \
    apt-get --quiet update && \
    apt-get --quiet --yes --no-install-recommends install \
        curl git build-essential libssl-dev libreadline-dev zlib1g-dev && \
    
    # Clone the correct rbenv repo
    git clone https://github.com/rbenv/rbenv.git /root/.rbenv && \
    git clone https://github.com/rbenv/ruby-build.git /root/.rbenv/plugins/ruby-build && \
    
    # Set up rbenv environment correctly
    export PATH="/root/.rbenv/bin:/root/.rbenv/shims:$PATH" && \
    eval "$(rbenv init -)" && \

    # Select the Ruby version based on OS
    if [ "${os}:${os_version}" = "ubuntu:trusty" ]; then \
        ruby_version="2.3.8"; \
    elif [ "${os}:${os_version}" = "ubuntu:jammy" ]; then \
        ruby_version="3.0.1"; \
    else \
        ruby_version="3.0.1"; \
    fi && \

    # Install the selected Ruby version
    rbenv install "$ruby_version" && \
    rbenv global "$ruby_version" && \

    # Ensure Ruby is installed and usable
    rbenv rehash && \
    ruby -v && \

    # Install Bundler and FPM
    gem install bundler && \
    gem install fpm --no-document

ENV LANG=C.UTF-8
# Persist rbenv path for subsequent steps
ENV PATH="/root/.rbenv/bin:/root/.rbenv/shims:$PATH"

# Build and test it
WORKDIR /tmp/build
ARG elixir_version
RUN wget --quiet https://github.com/elixir-lang/elixir/archive/v${elixir_version}.tar.gz
RUN tar xf v${elixir_version}.tar.gz
WORKDIR /tmp/build/elixir-${elixir_version}
RUN make
RUN make test
RUN make install PREFIX=/usr DESTDIR=/tmp/install

# # Package it
WORKDIR /tmp/output
ARG elixir_iteration
RUN . ~/.bashrc; \
  fpm -s dir -t deb \
  --chdir /tmp/install \
  --name elixir \
  --version ${elixir_version} \
  --package-name-suffix ${os_version} \
  --epoch 1 \
  --iteration ${elixir_iteration} \
  --package elixir_VERSION_ITERATION_otp_${erlang_version}~${os}~${os_version}_ARCH.deb \
  --maintainer "Erlang Solutions Ltd <support@erlang-solutions.com>" \
  --description "Elixir functional meta-programming language" \
  --url "https://erlang-solutions.com" \
  --architecture "all" \
  .

# --iteration ${elixir_iteration} \
# --depends "esl-erlang >= ${erlang_version}" \

# Sign it
RUN --mount=type=cache,id=${os}_${os_version},target=/var/cache/dnf,sharing=private \
  --mount=type=cache,id=${os}_${os_version},target=/var/cache/yum,sharing=private \
  apt-get --quiet update && apt-get --quiet --yes --no-install-recommends install \
  dpkg-sig

ARG gpg_pass
ARG gpg_key_id

COPY GPG-KEY-pmanager GPG-KEY-pmanager
RUN if [ "${os}:${os_version}" = "ubuntu:xenial" ]; then \
  gpg --import --batch --passphrase ${gpg_pass} GPG-KEY-pmanager; \
  dpkg-sig -g "--no-tty --passphrase ${gpg_pass}" -k ${gpg_key_id} --sign builder *.deb; \
  dpkg-sig --verify *.deb; \
  fi


# # Prove it is installable
FROM --platform=${TARGETPLATFORM} ${image} as testing
ARG erlang_version
ARG os
ARG os_version
ARG elixir_version

WORKDIR /tmp/output
COPY --from=builder /tmp/output .

# TODO this needs to be handled by --depends
# Install FPM dependencies
RUN --mount=type=cache,id=${os}_${os_version},target=/var/cache/apt,sharing=private \
  --mount=type=cache,id=${os}_${os_version},target=/var/lib/apt,sharing=private \
  apt-get --quiet update && apt-get --quiet --yes --no-install-recommends install \
  libsctp1 \
  procps \
  libssl-dev

COPY --from=builder /esl-erlang_${erlang_version}-1~${os}~${os_version}_amd64.deb .
RUN dpkg -i esl-erlang_${erlang_version}-1~${os}~${os_version}_amd64.deb

RUN dpkg -i elixir_${elixir_version}_1_otp_${erlang_version}~${os}~${os_version}_all.deb
RUN apt-get --quiet update && apt-get --quiet --yes --fix-broken install
RUN elixir -e "IO.puts 'Elixir is cool'"

# Export it
FROM scratch
COPY --from=testing /tmp/output/elixir*.deb /
