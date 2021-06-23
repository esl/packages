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
CACHE_FROM = "type=local,src=cache/$(OS)/$(OS_VERSION)"
CACHE_TO = "type=local,dest=cache/$(OS)/$(OS_VERSION)"
OUTPUT = "type=local,dest=build/$(OS)/$(OS_VERSION)"

override DEBIANS := $(foreach v,$(DEBIAN_VERSIONS),debian_$(v))
override UBUNTUS := $(foreach v,$(UBUNTU_VERSIONS),ubuntu_$(v))
override CENTOSES := $(foreach v,$(CENTOS_VERSIONS),centos_$(v))
override ALMALINUXES := $(foreach v,$(ALMALINUX_VERSIONS),almalinux_$(v))
override AMAZONLINUXES := $(foreach v,$(AMAZONLINUX_VERSIONS),amazonlinux_$(v))
override IMAGE_TAGS := $(DEBIANS) $(UBUNTUS) $(CENTOSES) $(ALMALINUXES) $(AMAZONLINUXES)

override ERLANG_BUILDS = $(foreach erlang,$(ERLANG_VERSIONS),$(foreach image_tag,$(IMAGE_TAGS),erlang_$(erlang)_$(image_tag)))
override ELIXIR_BUILDS = $(foreach elixir,$(ELIXIR_VERSIONS),$(foreach image_tag,$(IMAGE_TAGS),elixir_$(elixir)_$(image_tag)))

$(ERLANG_BUILDS): ERLANG_VERSION = $(word 2,$(subst _, ,$@))
$(ERLANG_BUILDS): OS = $(word 3,$(subst _, ,$@))
$(ERLANG_BUILDS): OS_VERSION = $(word 4,$(subst _, ,$@))
$(ERLANG_BUILDS): BUILDER = esl-buildx-erlang-$(OS)-$(OS_VERSION)
$(ERLANG_BUILDS): NPROC = $(shell nproc)
$(ERLANG_BUILDS): PLATFORM_COUNT = $(words $(shell echo "$(PLATFORMS)" | tr ',' ' '))
$(ERLANG_BUILDS): JOBS = $$(($(NPROC) / $(PLATFORM_COUNT)))

.PHONY: build
build: $(ERLANG_BUILDS) $(ELIXIR_BUILDS)

.PHONY: full
full:
	@$(MAKE) \
	ERLANG_VERSIONS="24.0.2 23.3.4.4 22.3.4.20 21.3.8.24" \
	ELIXIR_VERSIONS="1.12_22.3.4.9-1" \
	DEBIAN_VERSIONS="buster stretch" \
	UBUNTU_VERSIONS="focal bionic xenial trusty" \
	CENTOS_VERSIONS="8 7" \
	ALMALINUX_VERSIONS="8" \
	AMAZONLINUX_VERSIONS="2"

.PHONY: $(ERLANG_BUILDS)
$(ERLANG_BUILDS):
	@echo "Building erlang $(ERLANG_VERSION) for $(OS) $(OS_VERSION)"
	@docker buildx create --name "$(BUILDER)" --platform "$(PLATFORMS)" >/dev/null 2>&1 || true
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

$(ELIXIR_BUILDS): ELIXIR_VERSION = $(word 2,$(subst _, ,$@))
$(ELIXIR_BUILDS): ERLANG_VERSION = $(word 3,$(subst _, ,$@))
$(ELIXIR_BUILDS): OS = $(word 4,$(subst _, ,$@))
$(ELIXIR_BUILDS): OS_VERSION = $(word 5,$(subst _, ,$@))
$(ELIXIR_BUILDS): BUILDER = esl-buildx-elixir-$(OS)-$(OS_VERSION)
$(ELIXIR_BUILDS): JOBS = $(shell nproc)

.PHONY: $(ELIXIR_BUILDS)
$(ELIXIR_BUILDS):
	@echo "Building elixir $(ELIXIR_VERSION) against erlang $(ERLANG_VERSION) for $(OS) $(OS_VERSION)"
	@docker buildx create --name "$(BUILDER)" --platform "$(PLATFORMS)"  >/dev/null 2>&1 || true
	@docker buildx build \
	--platform="linux/amd64" \
	--builder "$(BUILDER)" \
	--build-arg jobs="$(JOBS)" \
	--build-arg os="$(OS)" \
	--build-arg os_version="$(OS_VERSION)" \
	--build-arg erlang_version="$(ERLANG_VERSION)" \
	--build-arg elixir_version="${ELIXIR_VERSION}" \
	--build-arg elixir_iteration="$(ELIXIR_ITERATION)" \
	--file "Dockerfile_elixir_$(OS)" \
	--cache-from="$(CACHE_FROM)" \
	--cache-to="$(CACHE_TO)" \
	--output "$(OUTPUT)" \
	. 2>&1 | tee $@.log

.PHONY: clean
clean:
	@rm -f *.log
	@rm -rf build/

.PHONY: destroy
destroy: clean
	@rm -rf cache/
	@docker buildx ls | grep docker-container | grep -Eo 'esl-buildx-[a-zA-Z0-9.-]+' | xargs -n1 docker buildx rm
