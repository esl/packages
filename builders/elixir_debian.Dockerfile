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
  libncurses5 \
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
  if [ $? -eq 0 ]; then \
  echo "libffi7"; \
  else \
  echo "libffi6"; \
  fi) \
  curl \
  libssl-dev\
  openssl\
  libreadline-dev \
  zlib1g-dev

# Ruby version and fpm
ENV PATH /root/.rbenv/bin:$PATH
RUN --mount=type=cache,id=${os}_${os_version},target=/var/cache/apt,sharing=private \
  --mount=type=cache,id=${os}_${os_version},target=/var/lib/apt,sharing=private \
  git clone https://github.com/sstephenson/rbenv.git /root/.rbenv; \
  git clone https://github.com/sstephenson/ruby-build.git /root/.rbenv/plugins/ruby-build; \
  /root/.rbenv/plugins/ruby-build/install.sh; \
  echo 'eval "$(rbenv init -)"' >> ~/.bashrc; \
  echo 'gem: --no-rdoc --no-ri' >> ~/.gemrc; \
  . ~/.bashrc; \
  if [ "${os}:${os_version}" = "ubuntu:trusty" ]; then \
  rbenv install 2.3.8; \
  rbenv global 2.3.8; \
  gem install bundler; \
  gem install git --no-document --version 1.7.0; \
  gem install json --no-rdoc --no-ri --version 2.2.0; \
  gem install ffi --no-rdoc --no-ri --version 1.9.25; \
  gem install fpm --no-rdoc --no-ri --version 1.11.0; \
  else \
  if [ "${os}:${os_version}" = "ubuntu:jammy" ]; then \
  rbenv install 3.0.1; \
  rbenv global 3.0.1; \
  gem install bundler; \
  gem install fpm --no-document --version 1.13.0; \
  else \
  rbenv install 2.6.6; \
  rbenv global 2.6.6; \
  gem install bundler; \
  gem install fpm --no-document --version 1.13.0; \
  fi \
  fi

ENV LANG=C.UTF-8

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

# Prove it is installable
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
  libncurses5 \
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
