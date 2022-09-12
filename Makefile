SHELL = /bin/sh

ifeq (, $(shell which jq))
$(error "jq not found!")
endif

ifeq (, $(shell which nproc))
$(error "nproc not found!")
endif

# Override these if you like
ERLANG_VERSIONS :=
ERLANG_ITERATION := 1
ELIXIR_VERSIONS :=
ELIXIR_ITERATION := 1
PLATFORMS := linux/amd64 linux/arm64
DEBIAN_VERSIONS :=
UBUNTU_VERSIONS :=
CENTOS_VERSIONS :=
ALMALINUX_VERSIONS :=
AMAZONLINUX_VERSIONS :=
ROCKYLINUX_VERSIONS :=
FEDORA_VERSIONS :=
CACHE_FROM = type=local,src=cache/$(OS)/$(OS_VERSION)
CACHE_TO = type=local,dest=cache/$(OS)/$(OS_VERSION)
OUTPUT = type=local,dest=build/$(OS)/$(OS_VERSION)

# Consult github remote to get latest maintenance tags
override ERLANG_MAINTS = \
	$(shell git ls-remote --tags --sort=-version:refname https://github.com/erlang/otp 'OTP-[2-9][0-9]*' | \
	grep "$$(git ls-remote --heads https://github.com/erlang/otp 'maint-[2-9][0-9]*' | awk '{print $$1}')" | \
	grep -Eo '[0-9]+\.[0-9.]+')
override ELIXIR_LATEST = \
	$(shell curl --fail https://api.github.com/repos/elixir-lang/elixir/releases?per_page=1 | jq -r '.[] | .tag_name')
	# $(shell curl --fail https://api.github.com/repos/elixir-lang/elixir/releases?per_page=1 | jq -r '.[] | .tag_name')_$(ELIXIR_OTP)

override DEBIANS = $(foreach v,$(DEBIAN_VERSIONS),debian_$(v))
override UBUNTUS = $(foreach v,$(UBUNTU_VERSIONS),ubuntu_$(v))
override CENTOSES = $(foreach v,$(CENTOS_VERSIONS),centos_$(v))
override ALMALINUXES = $(foreach v,$(ALMALINUX_VERSIONS),almalinux_$(v))
override AMAZONLINUXES = $(foreach v,$(AMAZONLINUX_VERSIONS),amazonlinux_$(v))
override ROCKYLINUXES = $(foreach v,$(ROCKYLINUX_VERSIONS),rockylinux_$(v))
override FEDORAS = $(foreach v,$(FEDORA_VERSIONS),fedora_$(v))
override ERLANG_IMAGE_TAGS = $(DEBIANS) $(UBUNTUS) $(CENTOSES) $(ALMALINUXES) $(AMAZONLINUXES) $(ROCKYLINUXES) $(FEDORAS)
override ELIXIR_IMAGE_TAGS = debian_buster centos_8

override ERLANG_BUILDS = $(foreach erlang,$(ERLANG_VERSIONS),$(foreach image_tag,$(ERLANG_IMAGE_TAGS),$(foreach platform,$(subst /,-,$(PLATFORMS)),erlang_$(erlang)_$(image_tag)_$(platform))))
override ELIXIR_BUILDS = $(foreach elixir,$(ELIXIR_VERSIONS),$(foreach image_tag,$(ELIXIR_IMAGE_TAGS),elixir_$(elixir)_$(image_tag)))

override LATEST_DEBIAN := buster
override LATEST_UBUNTU := focal
override LATEST_CENTOS := 8
override LATEST_FEDORA := 34

override FULL_DEBIAN := bullseye buster stretch
override FULL_UBUNTU := focal bionic xenial trusty
override FULL_CENTOS := 8 7
override FULL_FEDORA := 34 33

override ELIXIR_OTP := 22.3.4.9-1
override DEFAULT_ELIXIR := 12.2_$(ELIXIR_OTP)

.PHONY: custom
custom: $(ERLANG_BUILDS) $(ELIXIR_BUILDS)

ERLANG_VERSIONS = $(ERLANG_MAINTS)
ELIXIR_VERSIONS = $(ELIXIR_LATEST)
DEBIAN_VERSIONS = $(LATEST_DEBIAN)
UBUNTU_VERSIONS = $(LATEST_UBUNTU)
CENTOS_VERSIONS = $(LATEST_CENTOS)
FEDORA_VERSIONS = $(LATEST_FEDORA)

.PHONY: latest
latest: $(ERLANG_BUILDS) $(ELIXIR_BUILDS)

ERLANG_VERSIONS = $(ERLANG_MAINTS)
ELIXIR_VERSIONS = $(DEFAULT_ELIXIR)
DEBIAN_VERSIONS = $(FULL_DEBIAN)
UBUNTU_VERSIONS = $(FULL_UBUNTU)
CENTOS_VERSIONS = $(FULL_CENTOS)
FEDORA_VERSIONS = $(FULL_FEDORA)

.PHONY: full
full: $(ERLANG_BUILDS) $(ELIXIR_BUILDS)

ERLANG_VERSIONS =
ELIXIR_VERSIONS = $(DEFAULT_ELIXIR)
DEBIAN_VERSIONS = $(LATEST_DEBIAN)
UBUNTU_VERSIONS = $(LATEST_UBUNTU)
CENTOS_VERSIONS = $(LATEST_CENTOS)
FEDORA_VERSIONS = $(LATEST_FEDORA)

.PHONY: single
single: $(ERLANG_BUILDS)

erlang_%: ERLANG_VERSION = $(strip $(subst latest, $(word 1,$(ERLANG_MAINTS)), $(word 2,$(subst _, ,$@))))
# erlang_%: ERLANG_VERSION = $(strip $(subst latest, 25.0.3, $(word 2,$(subst _, ,$@))))
erlang_%: OS = $(word 3,$(subst _, ,$@))
erlang_%: OS_VERSION = $(word 4,$(subst _, ,$@))
erlang_%: IMAGE = $(OS):$(OS_VERSION)
erlang_%: PLATFORM = $(subst -,/,$(word 5,$(subst _, ,$@)))
erlang_%: BUILDER = esl-buildx-erlang
erlang_%: JOBS = $(shell nproc)

.PHONY: erlang_%
erlang_%:
	@echo "Building erlang $(ERLANG_VERSION) for $(OS) $(OS_VERSION) $(PLATFORM) with dockerfile builder/erlang_$(OS).Dockerfile and image $(IMAGE)"
	@docker buildx create --name "$(BUILDER)" --platform "$(PLATFORM)" >/dev/null 2>&1 || true
	@echo "Builder created"
	@date +%s > $@.start
	@docker buildx build \
	--platform "$(PLATFORM)" \
	--builder "$(BUILDER)" \
	--build-arg jobs="$(JOBS)" \
	--build-arg gpg_pass="$(GPG_PASS)" \
	--build-arg image="$(IMAGE)" \
	--build-arg os="$(OS)" \
	--build-arg TARGETPLATFORM="$(PLATFORM)" \
	--build-arg os_version="$(OS_VERSION)" \
	--build-arg erlang_version="$(ERLANG_VERSION)" \
	--build-arg erlang_iteration="$(ERLANG_ITERATION)" \
	--cache-from="$(CACHE_FROM)" \
	--cache-to="$(CACHE_TO)" \
	--output "$(OUTPUT)" \
	--file "builders/erlang_$(OS).Dockerfile" \
	.
	@date +%s > $@.end

elixir_%: ELIXIR_VERSION = $(strip $(subst v, ,$(subst latest, $(ELIXIR_LATEST), $(word 2,$(subst _, ,$@)))))
elixir_%: ERLANG_VERSION = $(strip $(subst latest, $(word 1, $(ERLANG_MAINTS)), $(word 3,$(subst _, ,$@))))
elixir_%: OS = $(word 4,$(subst _, ,$@))
elixir_%: OS_VERSION = $(word 5,$(subst _, ,$@))
elixir_%: PLATFORM = $(subst -,/,$(word 6,$(subst _, ,$@)))
elixir_%: IMAGE = $(OS):$(OS_VERSION)
elixir_%: BUILDER = esl-buildx-elixir
elixir_%: JOBS = $(shell nproc)

.PHONY: elixir_%
elixir_%:
	@echo "Building elixir $(ELIXIR_VERSION) against erlang $(ERLANG_VERSION) for $(OS) $(OS_VERSION) $(PLATFORM) with dockerfile builder/elixir_$(OS).Dockerfile"
	@docker buildx create --name "$(BUILDER)" >/dev/null 2>&1 || true
	@echo "Builder created"
	@date +%s > $@.start
	@docker buildx build \
	--platform "$(PLATFORM)" \
	--builder "$(BUILDER)" \
	--build-arg jobs="$(JOBS)" \
	--build-arg image="$(IMAGE)" \
	--build-arg os="$(OS)" \
	--build-arg os_version="$(OS_VERSION)" \
	--build-arg erlang_version="$(ERLANG_VERSION)" \
	--build-arg elixir_version="$(ELIXIR_VERSION)" \
	--build-arg elixir_iteration="$(ELIXIR_ITERATION)" \
	--file "builders/elixir_$(OS).Dockerfile" \
	--cache-from="$(CACHE_FROM)" \
	--cache-to="$(CACHE_TO)" \
	--output "$(OUTPUT)" \
	.
	@date +%s > $@.end

.PHONY: clean
clean:
	@rm -f *.log *.start *.end
	@rm -rf build/

.PHONY: destroy
destroy: clean
	@rm -rf cache/
	@docker buildx ls | grep docker-container | grep -Eo 'esl-buildx-[a-zA-Z0-9.-]+' | xargs -n1 docker buildx rm
