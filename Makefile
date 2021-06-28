SHELL = /bin/sh

# Override these if you like
ERLANG_VERSIONS :=
ERLANG_ITERATION := 1
ELIXIR_VERSIONS :=
ELIXIR_ITERATION := 1
PLATFORMS := linux/amd64,linux/arm64/v8
DEBIAN_VERSIONS :=
UBUNTU_VERSIONS :=
CENTOS_VERSIONS :=
ALMALINUX_VERSIONS :=
AMAZONLINUX_VERSIONS :=
CACHE_FROM = type=local,src=cache/$(OS)/$(OS_VERSION)
CACHE_TO = type=local,dest=cache/$(OS)/$(OS_VERSION)
OUTPUT = type=local,dest=build/$(OS)/$(OS_VERSION)

# Consult github remote to get latest maintenance tags
override ERLANG_MAINTS = \
	$(shell git ls-remote --tags --sort=-version:refname https://github.com/erlang/otp 'OTP-[2-9][0-9]*' | \
	grep "$$(git ls-remote --heads https://github.com/erlang/otp 'maint-[2-9][0-9]*' | awk '{print $$1}')" | \
	grep -Eo '[0-9]+\.[0-9.]+')

override DEBIANS = $(foreach v,$(DEBIAN_VERSIONS),debian_$(v))
override UBUNTUS = $(foreach v,$(UBUNTU_VERSIONS),ubuntu_$(v))
override CENTOSES = $(foreach v,$(CENTOS_VERSIONS),centos_$(v))
override ALMALINUXES = $(foreach v,$(ALMALINUX_VERSIONS),almalinux_$(v))
override AMAZONLINUXES = $(foreach v,$(AMAZONLINUX_VERSIONS),amazonlinux_$(v))
override ERLANG_IMAGE_TAGS = $(DEBIANS) $(UBUNTUS) $(CENTOSES) $(ALMALINUXES) $(AMAZONLINUXES)
override ELIXIR_IMAGE_TAGS = debian_buster centos_8

override ERLANG_BUILDS = $(foreach erlang,$(ERLANG_VERSIONS),$(foreach image_tag,$(ERLANG_IMAGE_TAGS),erlang_$(erlang)_$(image_tag)))
override ELIXIR_BUILDS = $(foreach elixir,$(ELIXIR_VERSIONS),$(foreach image_tag,$(ELIXIR_IMAGE_TAGS),elixir_$(elixir)_$(image_tag)))

.PHONY: custom
custom:
	$(MAKE) $(ERLANG_BUILDS) $(ELIXIR_BUILDS)

latest: ERLANG_VERSIONS = $(ERLANG_MAINTS)
latest: ELIXIR_VERSIONS = 1.12_22.3.4.9-1
latest: DEBIAN_VERSIONS = buster
latest: UBUNTU_VERSIONS = focal
latest: CENTOS_VERSIONS = 8

.PHONY: latest
latest:
	$(MAKE) $(ERLANG_BUILDS) $(ELIXIR_BUILDS)

full: ERLANG_VERSIONS = $(ERLANG_MAINTS)
full: ELIXIR_VERSIONS = 1.12_22.3.4.9-1
full: DEBIAN_VERSIONS = buster stretch
full: UBUNTU_VERSIONS = focal bionic xenial trusty
full: CENTOS_VERSIONS = 8 7
full: ALMALINUX_VERSIONS = 8
full: AMAZONLINUX_VERSIONS = 2

.PHONY: full
full:
	$(MAKE) $(ERLANG_BUILDS) $(ELIXIR_BUILDS)

erlang_%: ERLANG_VERSION = $(word 2,$(subst _, ,$@))
erlang_%: OS = $(word 3,$(subst _, ,$@))
erlang_%: OS_VERSION = $(word 4,$(subst _, ,$@))
erlang_%: BUILDER = esl-buildx-erlang-$(OS)-$(OS_VERSION)
erlang_%: NPROC = $(shell nproc)
erlang_%: PLATFORM_COUNT = $(words $(shell echo "$(PLATFORMS)" | tr ',' ' '))
erlang_%: JOBS = $$(($(NPROC) / $(PLATFORM_COUNT)))

.PHONY: erlang_%
erlang_%:
	@echo "Building erlang $(ERLANG_VERSION) for $(OS) $(OS_VERSION) $(PLATFORMS)"
	@docker buildx create --name "$(BUILDER)" --platform "$(PLATFORMS)" >/dev/null 2>&1 || true
	@date +%s > $@.start
	@docker buildx build \
	--platform "$(PLATFORMS)" \
	--builder "$(BUILDER)" \
	--build-arg jobs="$(JOBS)" \
	--build-arg os="$(OS)" \
	--build-arg os_version="$(OS_VERSION)" \
	--build-arg erlang_version="$(ERLANG_VERSION)" \
	--build-arg erlang_iteration="$(ERLANG_ITERATION)" \
	--cache-from="$(CACHE_FROM)" \
	--cache-to="$(CACHE_TO)" \
	--output "$(OUTPUT)" \
	--file "Dockerfile_erlang_$(OS)" \
	. 2>&1 | tee $@.log
	@date +%s > $@.end

elixir_%: ELIXIR_VERSION = $(word 2,$(subst _, ,$@))
elixir_%: ERLANG_VERSION = $(word 3,$(subst _, ,$@))
elixir_%: OS = $(word 4,$(subst _, ,$@))
elixir_%: OS_VERSION = $(word 5,$(subst _, ,$@))
elixir_%: BUILDER = esl-buildx-elixir-$(OS)-$(OS_VERSION)
elixir_%: JOBS = $(shell nproc)

.PHONY: elixir_%
elixir_%:
	@echo "Building elixir $(ELIXIR_VERSION) against erlang $(ERLANG_VERSION) for $(OS) $(OS_VERSION)"
	@docker buildx create --name "$(BUILDER)" --platform "$(PLATFORMS)"  >/dev/null 2>&1 || true
	@date +%s > $@.start
	@docker buildx build \
	--platform="linux/amd64" \
	--builder "$(BUILDER)" \
	--build-arg jobs="$(JOBS)" \
	--build-arg os="$(OS)" \
	--build-arg os_version="$(OS_VERSION)" \
	--build-arg erlang_version="$(ERLANG_VERSION)" \
	--build-arg elixir_version="$(ELIXIR_VERSION)" \
	--build-arg elixir_iteration="$(ELIXIR_ITERATION)" \
	--file "Dockerfile_elixir_$(OS)" \
	--cache-from="$(CACHE_FROM)" \
	--cache-to="$(CACHE_TO)" \
	--output "$(OUTPUT)" \
	. 2>&1 | tee $@.log
	@date +%s > $@.end

.PHONY: clean
clean:
	@rm -f *.log *.start *.end
	@rm -rf build/

.PHONY: destroy
destroy: clean
	@rm -rf cache/
	@docker buildx ls | grep docker-container | grep -Eo 'esl-buildx-[a-zA-Z0-9.-]+' | xargs -n1 docker buildx rm
