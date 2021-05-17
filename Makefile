PLATFORMS := linux/amd64 linux/arm64/v8 linux/arm/7
DEBIANS := $(foreach v,buster stretch jessie,"debian_$(v)-slim")
UBUNTUS := $(foreach v,focal bionic xenial trusty,"ubuntu_$(v)")
CENTOSES := $(foreach v,7 8,"centos_$(v)")

IMAGE_TAGS := $(DEBIANS) $(UBUNTUS) $(CENTOSES)

.PHONY: all
all: | setup build

ERLANGS = $(shell git --git-dir erlang tag --list 'OTP-*')
DISTS = $(foreach platform,$(PLATFORMS),$(foreach image_tag,$(IMAGE_TAGS),$(foreach erlang,$(ERLANGS),$(platform)_$(image_tag)_$(erlang))))

$(DISTS): PLATFORM = $(word 1,$(subst _, ,$@))
$(DISTS): IMAGE = $(word 2,$(subst _, ,$@))
$(DISTS): TAG = $(word 3,$(subst _, ,$@))
$(DISTS): ERLANG = $(word 4,$(subst _, ,$@))

build: $(DISTS)

.PHONY: $(DISTS)
$(DISTS):
	@echo "$(PLATFORM) $(IMAGE):$(TAG) $(ERLANG)"
	@docker run --rm \
	--platform $(PLATFORM) \
	--volume $(CURDIR):/mnt/input:ro \
	$(IMAGE):$(TAG) \
	/mnt/input/build.sh $(ERLANG)

.PHONY: setup
setup: erlang
	@git --git-dir=erlang fetch --tags

erlang:
	@git clone --bare https://github.com/erlang/otp erlang
