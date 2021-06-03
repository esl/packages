SHELL = /bin/sh

# Override these if you like
ERLANG_VERSIONS := 24.0.2 23.3.4.2 22.3.4.20 21.3.8.24
ELIXIR_VERSIONS := 1.12.0
PLATFORMS := linux/amd64,linux/arm64/v8
DEBIAN_VERSIONS := buster stretch
UBUNTU_VERSIONS := focal bionic xenial trusty
CENTOS_VERSIONS := 8 7

override DEBIANS := $(foreach v,$(DEBIAN_VERSIONS),debian_$(v))
override UBUNTUS := $(foreach v,$(UBUNTU_VERSIONS),ubuntu_$(v))
override CENTOSES := $(foreach v,$(CENTOS_VERSIONS),centos_$(v))
override IMAGE_TAGS := $(DEBIANS) $(UBUNTUS) $(CENTOSES)

override ERLANG_BUILDS = $(foreach image_tag,$(IMAGE_TAGS),$(foreach erlang,$(ERLANG_VERSIONS),erlang_$(image_tag)_$(erlang)))
override ELIXIR_BUILDS = $(foreach image_tag,$(IMAGE_TAGS),$(foreach elixir,$(ELIXIR_VERSIONS),elixir_$(image_tag)_$(elixir)))

$(ERLANG_BUILDS): OS = $(word 2,$(subst _, ,$@))
$(ERLANG_BUILDS): OS_VERSION = $(word 3,$(subst _, ,$@))
$(ERLANG_BUILDS): ERLANG_VERSION = $(word 4,$(subst _, ,$@))

override BUILDER = "esl-buildx"

.PHONY: all
all: $(ERLANG_BUILDS) $(ELIXIR_BUILDS)

.PHONY: $(ERLANG_BUILDS)
$(ERLANG_BUILDS): | create-buildx
	@echo "Building erlang $(ERLANG_VERSION) for $(OS) $(OS_VERSION)"
	@docker buildx build \
	--progress=plain \
	--platform "$(PLATFORMS)" \
	--builder "$(BUILDER)" \
	--build-arg os="$(OS)" \
	--build-arg os_version="$(OS_VERSION)" \
	--build-arg erlang_version="$(ERLANG_VERSION)" \
	--cache-from="type=local,src=cache" \
	--cache-to="type=local,dest=cache" \
	--output "type=local,dest=build/$@" \
	--file "Dockerfile_erlang_$(OS)" \
	. > $@.log 2>&1

$(ELIXIR_BUILDS): OS = $(word 2,$(subst _, ,$@))
$(ELIXIR_BUILDS): OS_VERSION = $(word 3,$(subst _, ,$@))
$(ELIXIR_BUILDS): ELIXIR_VERSION = $(word 4,$(subst _, ,$@))

.PHONY: $(ELIXIR_BUILDS)
$(ELIXIR_BUILDS): | create-buildx
	@echo "Building elixir $(ELIXIR_VERSION) for $(OS) $(OS_VERSION)"
	@docker buildx build \
	--progress=plain \
	--platform="linux/amd64" \
	--builder "$(BUILDER)" \
	--build-arg os="$(OS)" \
	--build-arg os_version="$(OS_VERSION)" \
	--build-arg elixir_version="${ELIXIR_VERSION}" \
	--file "Dockerfile_elixir_$(OS)" \
	--cache-from="type=local,src=cache" \
	--cache-to="type=local,dest=cache" \
	--output="type=local,dest=build/$@" \
	. > $@.log 2>&1

.PHONY: create-buildx
create-buildx:
	@docker buildx create --name "$(BUILDER)" --platform "$(PLATFORMS)" > /dev/null 2>&1 || true

.PHONY: clean
clean:
	@rm -rf build/ cache/
	@rm -f *.log
	@docker buildx rm "$(BUILDER)" || true
