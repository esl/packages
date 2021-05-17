#!/bin/sh -e

DEBIAN_FRONTEND=noninteractive apt-get --quiet update
DEBIAN_FRONTEND=noninteractive apt-get --quiet --yes install git

mkdir /tmp/build
cd /tmp/build
git --git-dir=/mnt/input/erlang archive --format tar $1 | tar xf -

DEBIAN_FRONTEND=noninteractive apt-get --quiet --yes install build-essential autoconf git libssl-dev libncurses5-dev
./otp_build autoconf
./configure
make
