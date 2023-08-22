# Binaries2

This repository contains a new approach to Erlang/Elixir package
creation and publishing.

The packaging repo consists of three distinct pieces: building from
source, packaging and publishing.

## Requirements

- nproc (coreutils)
- jq

## Building Erlang / Elixir

We wish to build any version of Erlang or Elixir for a variety of
different operating systems and hardware architectures. Collectively
the `Makefile` and `Dockerfile_*` files constitute this new build
system. The Makefile is parameterized, allowing run-time selection of
all these things. By default, nothing is built. You must set the
`ERLANG_VERSIONS`, `ELIXIR_VERSIONS`, `DEBIAN_VERSIONS`,
`UBUNTU_VERSIONS`, `CENTOS_VERSIONS` and `PLATFORMS` parameters.

The build system uses Docker and in particular the `buildx`
enhancements. Docker is configured for multi-arch support. The
`main.tf` and `cloud-init.yaml` file instantiates an appropriate AWS
instance, installs Docker, and configures it for multi-arch builds.

The `Dockerfile_*` files perform the entire build process, from
installing the build dependencies, testing, signing and finally
outputting a package. These files have some conditional
elements to account for differences across the currently supported range
of _versions_ of Debian/Ubuntu/CentOS in a way that is hopefully a guide
for any additional future nuances.

In order to improve build times, especially if a previous build has
been run (or partially run), the docker scripts use the `buildx`
"mount cache" feature, ensuring we cache any dependencies that we need
to downloaded. Foreign architecture builds are built with a
cross-compiler where available (Debian and Ubuntu).

The docker files are ordered such that as much work as
possible is done before the version-specific build begins, so that the
docker cache can be leveraged when building multiple erlang versions
for the same operating system targets.

Finally, the OTP smoke test must run successfully for an artifact to
be produced. Same pattern is applied for mongooseim and elixir.

## Package Generation

The build scripts (`Dockerfile_*`) use
[fpm](https://fpm.readthedocs.io/en/latest/) to generate
packages. This change radically simplifies the process of package
generation.

### Single erlang package example

If you check the [makefile](./Makefile#L97) you will see the different
parameters used in making a single erlang package. Let us say that
you would like to build Erlang 24.2.2 for rockylinux 8 targeting
`linux/am64`.

```bash
make  erlang_24.2.2_rockylinux_8_rockylinux_linux-amd64
```

## Implementing a new builder

There is no need to implement a new builder according to the current packages
that are listed in the ESL website. The builders folder contains two main
Dockerfiles per package to build that behave as the entry point for both main
distros, centos and debian. Like so:

 .
├──  elixir_debian.Dockerfile
├──  elixir_fedora.Dockerfile ⇒ elixir_centos.Dockerfile
...
├──  erlang_centos.Dockerfile
├──  erlang_rockylinux.Dockerfile ⇒ erlang_centos.Dockerfile
...
├──  mongooseim_debian.Dockerfile
└──  mongooseim_ubuntu.Dockerfile ⇒ mongooseim_debian.Dockerfile
...

The others are just symbolic links. Meaning that if we want to implement a new
builder a first good step would be to copy the main centos or debian Dockerfiles
and rename them accordingly.

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
is addressed by the [Acquire-By-Hash](https://wiki.debian.org/DebianRepository/Format#Acquire-By-Hash)
feature, in much the same way as `createrepo` does for
CentOS.

We could enhance our current scripting to do these two things but
rather than do that I think it is better to adopt a high level tool.

I have chosen [Aptly](https://www.aptly.info/doc/overview/) for this
work.

### Deploying to Production

Finally the new site is here. As of <Date>, we will be transitioning away from the old packages system, but fear not! The legacy packages will remain accessible at on packages.erlang-solutions.com and archives.erlang-solutions.com for your convenience. And to avoid issues with current pipelines or workflows.

- https://binaries2.erlang-solutions.com

### Installation Instructions

Add the Erlang Solutions public key for \"apt-secure\" using following commands::

<code>wget https://binaries2.erlang-solutions.com/GPG-KEY-pmanager.asc\nsudo apt-key add GPG-KEY-pmanager.asc\n</code>

To add Erlang Solutions repository (including our public key for apt-secure) to your system, call the following commands:

adding the repository entry manually
Add one of the following lines to your /etc/apt/sources.list (according to your distribution):

<code>deb http://binaries2.erlang-solutions.com/ubuntu/ jammy-esl-erlang-25 contrib</code>

<code>deb http://binaries2.erlang-solutions.com/debian/ bullseye-elixir-1.15 contrib</code>

<code>deb http://binaries2.erlang-solutions.com/ubuntu/ bionic-mongooseim-6 contrib</code>

## Contributing

Review [Contribution Guidelines](CONTRIBUTING.md)

## TO-DO
- Create deb and rpm autoinstallable ESL sources
- Bugfixing: Solve ARM64 issue
- Stabilization of the new platform
