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

# Setup EPEL
RUN --mount=type=cache,id=${os}_${os_version},target=/var/cache/dnf,sharing=private \
    --mount=type=cache,id=${os}_${os_version},target=/var/cache/yum,sharing=private \
    if [ "${os}" = "centos" -o "${os}" = "almalinux" -o "${os}" = "rockylinux" ]; then \
    yumdnf install -y epel-release; \
    fi

# Install Erlang/OTP dependencies
RUN --mount=type=cache,id=${os}_${os_version},target=/var/cache/dnf,sharing=private \
    --mount=type=cache,id=${os}_${os_version},target=/var/cache/yum,sharing=private \
    yumdnf install -y \
    autoconf \
    automake \
    bison \
    flex \
    gcc \
    gcc-c++ \
    git \
    java-11-openjdk-devel \
    libxslt-devel \
    libxslt \
    lksctp-tools-devel \
    make \
    ncurses-devel \
    openssl \
    openssl-devel \
    unixODBC-devel \
    wget \
    wxGTK3-devel

# Install FPM dependences
RUN --mount=type=cache,id=${os}_${os_version},target=/var/cache/dnf,sharing=private \
    --mount=type=cache,id=${os}_${os_version},target=/var/cache/yum,sharing=private \
    yumdnf install -y \
    gcc \
    make \
    rpm-build \
    libffi-devel \
    curl \
    git \
    readline-devel \
    zlib-devel && \
    yum remove -y ruby ruby-devel

# Install FPM
ENV PATH /root/.rbenv/bin:$PATH
RUN --mount=type=cache,id=${os}_${os_version},target=/var/cache/apt,sharing=private \
    --mount=type=cache,id=${os}_${os_version},target=/var/lib/apt,sharing=private \
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


# Build it
WORKDIR /tmp/build
ARG erlang_version
RUN wget --quiet https://github.com/erlang/otp/releases/download/OTP-${erlang_version}/otp_src_${erlang_version}.tar.gz
RUN tar xf otp_src_${erlang_version}.tar.gz
ENV ERL_TOP=/tmp/build/otp_src_${erlang_version}
WORKDIR $ERL_TOP
RUN if [ ! -f configure ]; then \
    ./otp_build autoconf; \
    fi
ENV CFLAGS="-g -O2 -fstack-protector-strong"
ENV LDFLAGS="-Wl,-z,relro"
RUN ./configure \
    --prefix=/usr \
    --enable-dirty-schedulers \
    --enable-dynamic-ssl-lib \
    --enable-kernel-poll \
    --enable-sctp \
    --with-java \
    --with-ssl

ARG jobs
RUN make --jobs=${jobs}

# Test it
RUN make --jobs=${jobs} release_tests
WORKDIR $ERL_TOP/release/tests/test_server
RUN $ERL_TOP/bin/erl -noshell -s ts install -s ts smoke_test batch -s init stop
RUN if grep -q '=failed *[1-9]' ct_run.test_server@*/*/run.*/suite.log; then \
    echo "One or more tests failed."; \
    grep -C 10 '=result *failed:' ct_run.test_server@*/*/run.*/suite.log; \
    exit 1; \
    fi

WORKDIR $ERL_TOP
RUN make --jobs=${jobs} docs DOC_TARGETS="chunks man"
RUN mkdir -p /tmp/install
RUN make --jobs=${jobs} DESTDIR=/tmp/install install
RUN make --jobs=${jobs} DESTDIR=/tmp/install install-docs DOC_TARGETS="chunks man"

# Package it
WORKDIR /tmp/output
ARG erlang_iteration
ADD determine-license /usr/local/bin
RUN . ~/.bashrc; \
    fpm -s dir -t rpm \
    --chdir /tmp/install \
    --name esl-erlang \
    --version ${erlang_version} \
    --package-name-suffix ${os_version} \
    --epoch 1 \
    --iteration ${erlang_iteration} \
    --package esl-erlang_VERSION_ITERATION~${os}~${os_version}_ARCH.rpm \
    --category interpreters \
    --description "Concurrent, real-time, distributed functional language" \
    --url "https://erlang-solutions.com" \
    --license "$(determine-license ${erlang_version})" \
    --depends 'openssl-libs' \
    --provides "erlang = ${erlang_version}-${erlang_iteration}" \
    --provides "erlang-erts = ${erlang_version}-${erlang_iteration}" \
    --provides "erlang-inets = ${erlang_version}-${erlang_iteration}" \
    .

# Test install
FROM ${image} as install
ARG os
ARG os_version

WORKDIR /tmp/output
COPY --from=builder /tmp/output .
ADD yumdnf /usr/local/bin/

# Fix centos 8 mirrors
RUN --mount=type=cache,id=${os}_${os_version},target=/var/cache/dnf,sharing=private \
    --mount=type=cache,id=${os}_${os_version},target=/var/cache/yum,sharing=private \
    if [ "${os}:${os_version}" = "centos:8" ]; then \
    cd /etc/yum.repos.d/; \
    sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-* ; \
    sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*; \
    fi

# Setup EPEL
RUN --mount=type=cache,id=${os}_${os_version},target=/var/cache/dnf,sharing=private \
    --mount=type=cache,id=${os}_${os_version},target=/var/cache/yum,sharing=private \
    if [ "${os}" = "centos" -o "${os}" = "almalinux" -o "${os}" = "rockylinux" ]; then \
    yumdnf install -y epel-release; \
    fi

RUN yumdnf install -y ./*.rpm
RUN erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().'  -noshell

# Export it
FROM scratch
COPY --from=install /tmp/output /
