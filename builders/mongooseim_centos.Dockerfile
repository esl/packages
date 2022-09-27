# -*- mode: dockerfile -*-
# syntax = docker/dockerfile:1.2
ARG image
FROM ${image} as builder
ARG os
ARG os_version
ADD yumdnf /usr/local/bin/

# Fix centos 8 mirrors
RUN --mount=type=cache,id=${os}_${os_version},target=/var/cache/dnf,sharing=private \
  --mount=type=cache,id=${os}_${os_version},target=/var/cache/yum,sharing=private \
  if [ "${os}:${os_version}" = "centos:8" ]; then \
  cd /etc/yum.repos.d/; \
  sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-* ; \
  sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*; \
  fi

# Setup ESL repo
RUN --mount=type=cache,id=${os}_${os_version},target=/var/cache/dnf,sharing=private \
  --mount=type=cache,id=${os}_${os_version},target=/var/cache/yum,sharing=private \
  yumdnf install -y \
  git \
  wget

# Setup EPEL
RUN --mount=type=cache,id=${os}_${os_version},target=/var/cache/dnf,sharing=private \
  --mount=type=cache,id=${os}_${os_version},target=/var/cache/yum,sharing=private \
  if [ "${os}" = "centos" -o "${os}" = "almalinux" ]; then \
  yumdnf install -y epel-release; \
  fi

# Install Erlang/OTP
ARG erlang_version
RUN --mount=type=cache,id=${os}_${os_version},target=/var/cache/dnf,sharing=private \
  --mount=type=cache,id=${os}_${os_version},target=/var/cache/yum,sharing=private \
  wget https://esl-erlang.s3.eu-west-2.amazonaws.com/${os}/${os_version}/esl-erlang_${erlang_version}_1~${os}~${os_version}_x86_64.rpm && \
  yumdnf install -y esl-erlang_${erlang_version}_1~${os}~${os_version}_x86_64.rpm

# Install FPM and mongooseim dependencies
RUN --mount=type=cache,id=${os}_${os_version},target=/var/cache/dnf,sharing=private \
  --mount=type=cache,id=${os}_${os_version},target=/var/cache/yum,sharing=private \
  yumdnf install -y \
  gcc \
  gcc-c++ \
  openssl \
  openssl-devel \
  unixODBC-devel \
  make \
  rpm-build \
  curl \
  git \
  readline-devel \
  zlib-devel && \
  yum remove -y ruby ruby-devel

# Install FPM
ENV PATH /root/.rbenv/bin:$PATH
RUN --mount=type=cache,id=${os}_${os_version},target=/var/cache/dnf,sharing=private \
  --mount=type=cache,id=${os}_${os_version},target=/var/cache/yum,sharing=private \
  git clone https://github.com/sstephenson/rbenv.git /root/.rbenv; \
  git clone https://github.com/sstephenson/ruby-build.git /root/.rbenv/plugins/ruby-build; \
  /root/.rbenv/plugins/ruby-build/install.sh; \
  echo 'eval "$(rbenv init -)"' >> ~/.bashrc; \
  echo 'gem: --no-rdoc --no-ri' >> ~/.gemrc; \
  . ~/.bashrc; \
  if [ "${os}:${os_version}" = "centos:7" -o "${os}:${os_version}" = "amazonlinux:2" ]; then \
  # fpm 1.12 requires ruby 2.3.8
  rbenv install 2.3.8; \
  rbenv global 2.3.8; \
  gem install bundler; \
  gem install git --no-document --version 1.7.0; \
  gem install fpm --no-document --version 1.12.0; \
  else \
  # fpm 1.13 requires ruby 2.6.
  rbenv install 2.6.6; \
  rbenv global 2.6.6; \
  gem install bundler; \
  gem install fpm --no-document --version 1.13.0; \
  fi

# Ensure UTF-8 locale
RUN --mount=type=cache,id=${os}_${os_version},target=/var/cache/dnf,sharing=private \
  --mount=type=cache,id=${os}_${os_version},target=/var/cache/yum,sharing=private \
  if [ "${os}:${os_version}" = "centos:8" -o "${os}" = "rockylinux"]; then \
  yumdnf install -y \
  glibc-locale-source \
  glibc-all-langpacks \
  langpacks-en && \
  localedef -i en_US -f UTF-8 en_US.UTF-8; \
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
  fpm -s dir -t rpm \
  --chdir /tmp/install \
  --maintainer "Erlang Solutions Ltd <support@erlang-solutions.com>" \
  --description "MongooseIM is Erlang Solutions' robust, scalable and efficient XMPP server" \
  --url "https://erlang-solutions.com" \
  --architecture "all" \
  --name mongooseim \
  --package mongooseim_VERSION_ITERATION_otp_${erlang_version}~${os}~${os_version}_ARCH.rpm \
  --version ${mongooseim_version} \
  --epoch 1 \
  --iteration ${mongooseim_iteration} \
  --package-name-suffix ${os_version} \
  .
#    --depends "esl-erlang >= ${erlang_version}" \

# Sign it
RUN --mount=type=cache,id=${os}_${os_version},target=/var/cache/dnf,sharing=private \
  --mount=type=cache,id=${os}_${os_version},target=/var/cache/yum,sharing=private \
  yumdnf install -y pinentry

ARG gpg_pass
ARG gpg_p_key
ENV GPG_PASS gpg_pass

COPY GPG-KEY-pmanager GPG-KEY-pmanager
COPY .rpmmacros /root/.rpmmacros

RUN echo ${gpg_p_key} | tr ';' '\n' > GPG-KEY-PRIV-pmanager; \
  gpg --import --batch --passphrase ${GPG_PASS} GPG-KEY-PRIV-pmanager; \
  rpm --import GPG-KEY-pmanager; \
  rpm --addsign *.rpm; \
  rpm -K *.rpm

# Test install
FROM ${image} as install
ARG os
ARG os_version
ARG erlang_version

WORKDIR /tmp/output
ADD yumdnf /usr/local/bin/

# Fix centos 8 mirrors
RUN --mount=type=cache,id=${os}_${os_version},target=/var/cache/dnf,sharing=private \
  --mount=type=cache,id=${os}_${os_version},target=/var/cache/yum,sharing=private \
  if [ "${os}:${os_version}" = "centos:8" ]; then \
  cd /etc/yum.repos.d/; \
  sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-* ; \
  sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*; \
  fi

# # Setup EPEL
RUN --mount=type=cache,id=${os}_${os_version},target=/var/cache/dnf,sharing=private \
  --mount=type=cache,id=${os}_${os_version},target=/var/cache/yum,sharing=private \
  if [ "${os}" = "centos" -o "${os}" = "almalinux" -o "${os}" = "rockylinux" ]; then \
  yumdnf install -y epel-release wget; \
  fi

COPY --from=builder /tmp/output .

# TODO this needs to be handled by --depends
COPY --from=builder /esl-erlang_${erlang_version}_1~${os}~${os_version}_x86_64.rpm .

RUN yumdnf install -y esl-erlang_${erlang_version}_1~${os}~${os_version}_x86_64.rpm
RUN yumdnf install -y ./*.rpm
RUN rm -rf ./esl-erlang*.rpm
RUN mongooseimctl print_install_dir

COPY --from=builder /TESTS /TESTS
WORKDIR /TESTS
RUN ./smoke_test.sh

# # Export it
FROM scratch
COPY --from=install /tmp/output/mongooseim*.rpm /
