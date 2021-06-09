# Packages2


This repository contains a new approach to Erlang/Elixir package
creation and publishing. As I'm not familiar with ESL's existing
infrastructure setup or tooling I cannot fully deliver this work to
production on my own. Hence, I describe the components here and
further describe how they should be deployed and managed.

The packaging repo consists of three distinct pieces: building from
source, packaging and publishing.

## Building Erlang / Elixir

We wish to build any version of Erlang or Elixir for a variety of
different operating systems and hardware architectures. Collectively
the `Makefile` and `Dockerfile_*` files constitute this new build
system. The Makefile is parameterized, allowing run-time selection of
all these things. It defaults to building the latest elixir build and
the latest patch release of the four most recent major releases of
Erlang for the last two Debian releases, the last four Ubuntu LTS
releases, and the last two CentOS releases, for both amd64 and arch64.

The build system uses Docker and in particular the `buildx`
enhancements. Docker is configured for multi-arch support. The
`main.tf` and `cloud-init.yaml` file instantiates an appropriate AWS
instance, installs Docker, and configures it for multi-arch builds.

The production version of this should attach an `EBS` volume to the
instance and adjust the `cache-from`, `cache-to` and `output`
arguments to `buildx` to point to this volume. The volume should be
preserved beyond the termination of the instance, and re-attached to a
future instance, when new Erlang or Elixir versions are released by
upstream.

The `Dockerfile_*` files perform the entire build process, from
installing the build dependencies, testing and finally outputting a
package. These files have some conditional elements to account for
differences across the currently supported range of _versions_ of
Debian/Ubuntu/CentOS in a way that is hopefully a guide for any
additional future nuances.

In order to improve build times, especially if a previous build has
been run (or partially run), the docker scripts use the `buildx`
"mount cache" feature, ensuring we cache any dependencies that we need
to downloaded.

Additionally the docker files are ordered such that as much work as
possible is done before the version-specific build begins, so that the
docker cache can be leveraged when building multiple erlang versions
for the same operating system targets.

## Package Generation

The build scripts (`Dockerfile_*`) use
[fpm](https://fpm.readthedocs.io/en/latest/) to generate
packages. This change radically simplifies the process of package
generation.

## Publishing

For CentOS releases it is still the best approach to continue using
`createrepo` and so there is no additional work in this
repo. `createrepo` is appropriate because it includes the digest of
each index file in the filename. This is important due to the
CloudFront caching we apply in front of our package repository and is
the reason the "corruption" issue that the Debian and Ubuntu packages
currently face does not occur there.

Debian/Ubuntu repositories have traditionally suffered from a number
of race conditions that render them temporarily corrupt. This surfaces
during normal Debian mirroring but also with our custom scripting in
`packages-pipeline`.

There are two fundamental issues, both of which
are significantly compounded by the 24 hour CloudFront caching policy
we add on top.

Firstly, the top-level `Release` file and its signature
in `Release.gpg`. A client must see a consistent set of these files,
or else it will (correctly) conclude that the signature is not
valid. This is addressed by the `InRelease` file which
`apt-get` attempts to fetch first. Our current scripts do not generate
it but the new approach will. The `InRelease` file is a
cleartext-signed version of the `Release` file, so the signature can
always be successfully verified.

Secondly, the `Release` file contains the checksums of the `Packages*`
files, so a client that sees a new `Release` file but a cached
`Packages` file can also conclude that our repository is corrupt. This
is addressed by the [Acquire-By-Hash](
https://wiki.debian.org/DebianRepository/Format#Acquire-By-Hash)
feature, in much the same way as `createrepo` does for
CentOS.

We could enhance our current scripting to do these two things but
rather than do that I think it is better to adopt a high level tool.

I have chosen [Aptly](https://www.aptly.info/doc/overview/) for this
work and include several scripts that demonstrate its successful
usage.

### create_aptly_repos

This script creates some empty Aptly repositories. Note here that we
build separate repositories for the last four major Erlang
releases. The intent is to allow a user or customer to receive patch
releases to their current erlang install without being exposed to the
risk of a breaking change (e.g, going from 23 to 24). A simple symlink
can be established for those that wish to always have the latest (the
exact same approach that Debian takes with `stable`, `testing` and
`unstable).

### import_debs_to_aptly

The filenames of the `.deb` artifacts generated by the build scripts
are carefully chosen so that we can infer exactly which Aptly repo to
add them to. This script shows how to extract this information and
then use it to update the repository.

### publish_aptly_repos

This script shows how to publish the Aptly repositories to an S3
volume using the `Acquire-By-Hash` feature. The S3 volume can be be
published indirectly via CloudFront as it is today.


