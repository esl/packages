SHELL = /bin/sh

# Override these if you like
ERLANG_VERSIONS := 24.0.2 23.3.4.2 22.3.4.20 21.3.8.24
ERLANG_ITERATION := 1
ELIXIR_VERSIONS := 1.12.0
ELIXIR_ITERATION := 1
PLATFORMS := linux/amd64,linux/arm64/v8
DEBIAN_VERSIONS := buster stretch
UBUNTU_VERSIONS := focal bionic xenial trusty
CENTOS_VERSIONS := 8 7

override DEBIANS := $(foreach v,$(DEBIAN_VERSIONS),debian_$(v))
override UBUNTUS := $(foreach v,$(UBUNTU_VERSIONS),ubuntu_$(v))
override CENTOSES := $(foreach v,$(CENTOS_VERSIONS),centos_$(v))
override IMAGE_TAGS := $(DEBIANS) $(UBUNTUS) $(CENTOSES)

override ERLANG_BUILDS = $(foreach erlang,$(ERLANG_VERSIONS),$(foreach image_tag,$(IMAGE_TAGS),erlang_$(erlang)_$(image_tag)))
override ELIXIR_BUILDS = $(foreach elixir,$(ELIXIR_VERSIONS),$(foreach image_tag,$(IMAGE_TAGS),elixir_$(elixir)_$(image_tag)))

$(ERLANG_BUILDS): ERLANG_VERSION = $(word 2,$(subst _, ,$@))
$(ERLANG_BUILDS): OS = $(word 3,$(subst _, ,$@))
$(ERLANG_BUILDS): OS_VERSION = $(word 4,$(subst _, ,$@))
$(ERLANG_BUILDS): BUILDER = "esl-buildx-erlang-$(OS)-$(OS_VERSION)"

.PHONY: all
all: $(ERLANG_BUILDS) $(ELIXIR_BUILDS)

.PHONY: $(ERLANG_BUILDS)
$(ERLANG_BUILDS):
	@echo "Building erlang $(ERLANG_VERSION) for $(OS) $(OS_VERSION)"
	@docker buildx create --name "$(BUILDER)" --platform "$(PLATFORMS)" || true
	@docker buildx build \
	--progress=plain \
	--platform "$(PLATFORMS)" \
	--builder "$(BUILDER)" \
	--build-arg os="$(OS)" \
	--build-arg os_version="$(OS_VERSION)" \
	--build-arg erlang_version="$(ERLANG_VERSION)" \
	--build-arg erlang_iteration="$(ERLANG_ITERATION)" \
	--cache-from="type=local,src=cache" \
	--cache-to="type=local,dest=cache" \
	--output "type=local,dest=build/$@" \
	--file "Dockerfile_erlang_$(OS)" \
	. 2>&1 | tee $@.log

$(ELIXIR_BUILDS): ELIXIR_VERSION = $(word 2,$(subst _, ,$@))
$(ELIXIR_BUILDS): OS = $(word 3,$(subst _, ,$@))
$(ELIXIR_BUILDS): OS_VERSION = $(word 4,$(subst _, ,$@))
$(ELIXIR_BUILDS): BUILDER = "esl-buildx-elixir-$(OS)-$(OS_VERSION)"

.PHONY: $(ELIXIR_BUILDS)
$(ELIXIR_BUILDS):
	@echo "Building elixir $(ELIXIR_VERSION) for $(OS) $(OS_VERSION)"
	@docker buildx create --name "$(BUILDER)" --platform "$(PLATFORMS)" || true
	@docker buildx build \
	--progress=plain \
	--platform="linux/amd64" \
	--builder "$(BUILDER)" \
	--build-arg os="$(OS)" \
	--build-arg os_version="$(OS_VERSION)" \
	--build-arg elixir_version="${ELIXIR_VERSION}" \
	--build-arg elixir_iteration="$(ELIXIR_ITERATION)" \
	--file "Dockerfile_elixir_$(OS)" \
	--cache-from="type=local,src=cache" \
	--cache-to="type=local,dest=cache" \
	--output="type=local,dest=build/$@" \
	. 2>&1 | tee $@.log

.PHONY: clean
clean:
	@rm -rf build/ cache/
	@rm -f *.log
	@docker buildx ls | grep docker-container | grep -Eo 'esl-buildx-[a-zA-Z0-9.-]+' | xargs -n1 docker buildx rm
