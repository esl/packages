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
  git \
  gnupg \
  $(apt-cache show "procps" > /dev/null 2>&1; \
  if [ $? -eq 0 ]; then \
  echo "procps"; \
  fi) \
  $(apt-cache show "libncurses5" > /dev/null 2>&1; \
  if [ $? -eq 0 ]; then \
  echo "libncurses5"; \
  fi) \
  wget

# Install Erlang/OTP
ARG erlang_version
RUN --mount=type=cache,id=${os}_${os_version},target=/var/cache/apt,sharing=private \
  --mount=type=cache,id=${os}_${os_version},target=/var/lib/apt,sharing=private \
  wget https://esl-erlang.s3.eu-west-2.amazonaws.com/${os}/${os_version}/esl-erlang_${erlang_version}-1~${os}~${os_version}_amd64.deb && \
  dpkg -i esl-erlang_${erlang_version}-1~${os}~${os_version}_amd64.deb

# Install FPM and mongooseim dependencies
RUN --mount=type=cache,id=${os}_${os_version},target=/var/cache/apt,sharing=private \
  --mount=type=cache,id=${os}_${os_version},target=/var/lib/apt,sharing=private \
  apt-get --quiet update && apt-get --quiet --yes --no-install-recommends install \
  gcc \
  make \
  $(apt-cache show "libffi6" > /dev/null 2>&1; \
  if [ $? -eq 0 ]; then \
  echo "libffi6"; \
  fi) \
  curl \
  libssl-dev\
  openssl\
  unixodbc-dev\
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

# Build it
WORKDIR /tmp/build
ARG mongooseim_version

RUN wget --quiet https://github.com/esl/MongooseIM/archive/${mongooseim_version}.tar.gz
RUN tar xf ${mongooseim_version}.tar.gz

WORKDIR /tmp/build/MongooseIM-${mongooseim_version}

RUN ./tools/configure with-all prefix=/tmp/install user=root system=yes && \
  cat configure.out rel/configure.vars.config
RUN make
RUN make test
RUN make install

# TODO document this magic

RUN mkdir /TESTS \
  && cp ./tools/pkg/scripts/smoke_test.sh /TESTS/ \
  && cp ./tools/pkg/scripts/smoke_templates.escript /TESTS/ \
  && cp ./tools/wait-for-it.sh /TESTS/

# TODO document this magic

WORKDIR /tmp/install

RUN sed -i -e 's/tmp\/install\///g' ./etc/mongooseim/app.config
RUN sed -i -e 's/tmp\/install\///g' ./usr/bin/mongooseimctl
RUN sed -i -e 's/tmp\/install\///g' ./usr/lib/mongooseim/erts-*/bin/nodetool
RUN sed -i -e 's/tmp\/install\///g' ./usr/lib/mongooseim/etc/app.config.example
RUN sed -i -e 's/tmp\/install\///g' ./usr/lib/mongooseim/bin/mongooseim
RUN sed -i -e 's/tmp\/install\///g' ./usr/lib/mongooseim/bin/mongooseimctl

# Package it
WORKDIR /tmp/output

ARG mongooseim_iteration
RUN . ~/.bashrc; \
  fpm -s dir -t deb \
  --chdir /tmp/install \
  --maintainer "Erlang Solutions Ltd <support@erlang-solutions.com>" \
  --description "Elixir functional meta-programming language" \
  --url "https://erlang-solutions.com" \
  --architecture "all" \
  --name mongooseim \
  --package mongooseim_VERSION_ITERATION_ARCH.deb \
  --version ${mongooseim_version} \
  --epoch 1 \
  --iteration ${mongooseim_iteration} \
  --package-name-suffix ${os_version} \
  .
#    --depends "esl-erlang >= ${erlang_version}" \

# Test install
FROM ${image} as install
ARG os
ARG os_version
ARG erlang_version

WORKDIR /tmp/output

COPY --from=builder /tmp/output .

# TODO this needs to be handled by --depends
# Install FPM dependencies
RUN --mount=type=cache,id=${os}_${os_version},target=/var/cache/apt,sharing=private \
  --mount=type=cache,id=${os}_${os_version},target=/var/lib/apt,sharing=private \
  apt-get --quiet update && apt-get --quiet --yes --no-install-recommends install \
  libsctp1 \
  libncurses5 \
  procps

COPY --from=builder /esl-erlang_${erlang_version}-1~${os}~${os_version}_amd64.deb .
RUN dpkg -i esl-erlang_${erlang_version}-1~${os}~${os_version}_amd64.deb
RUN dpkg -i *.deb || true

RUN apt-get --quiet update && apt-get --quiet --yes --fix-broken install
RUN rm -rf ./esl-erlang*.deb

RUN mongooseimctl print_install_dir

COPY --from=builder /TESTS /TESTS
WORKDIR /TESTS
RUN ./smoke_test.sh

# Export it
FROM scratch
COPY --from=install /tmp/output /
