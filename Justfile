platform := 'linux/amd64'

alpine_version := "3.22"
alpine_builder_tag := "alpine-builder:" + alpine_version + "-latest"
alpine_mirror := "http://dl-cdn.alpinelinux.org/alpine/"
alpine_main_repo := alpine_mirror + "v" + alpine_version + "/main"
alpine_community_repo := alpine_mirror + "v" + alpine_version + "/community"

aports_repo := "https://github.com/alpinelinux/aports.git"
aports_dir := "aports"

build_user := "imagebuilder"
build_keys := `find keys/ -type f -print -quit 2> /dev/null || true`

shellspec_dir := "shellspec"
shellspec_repo := "https://github.com/shellspec/shellspec.git"
shellspec_tag := "0.28.1"


# List all recipes
@default:
    just --list --unsorted

# Build all Alpine images
build-all: \
    (build "homeassistant" "linux/amd64") \
    (build "k0s_worker" "linux/amd64") \
    (build "rpi_basic" "linux/arm/v6") \
    (build "rpi_basic" "linux/arm64") \
    (build "rpi_firewall" "linux/arm64") \
    (build "rpi_k0s_controller" "linux/arm64") \
    (build "rpi_ruuvi" "linux/arm/v6") \
    (build "rpi_snapcast_client" "linux/arm/v6")


# Build single Alpine image
build image platform=platform:
    @echo "Building {{image}} ..."
    @if [ -z "{{build_keys}}" ]; then echo "No build keys yet.  Run \`just abuild-keygen\`"; exit 1; fi
    @mkdir -p out
    docker run --rm \
      --user $(id -u) \
      --platform={{platform}} \
      --volume $(pwd)/{{aports_dir}}:/aports:ro \
      --volume $(pwd)/scripts:/home/{{build_user}}/.mkimage:ro \
      --volume $(pwd)/keys:/home/{{build_user}}/.abuild:ro \
      --volume $(pwd)/overlays:/overlays:ro \
      --volume $(pwd)/out:/out \
      --env HL_OVERLAY_DIR="${HL_OVERLAY_DIR:-}" \
      --env HL_HOSTNAME="${HL_HOSTNAME:-}" \
      --env HL_NTP_SERVER="${HL_NTP_SERVER:-}" \
      --env HL_SNAPCAST_SERVER="${HL_SNAPCAST_SERVER:-}" \
      --env HL_SSH_KEY_URL="${HL_SSH_KEY_URL:-}" \
      --env HL_WIFI_SSID="${HL_WIFI_SSID:-}" \
      --env HL_WIFI_PSK="${HL_WIFI_PSK:-}" \
      {{alpine_builder_tag}} \
        sh -x /aports/scripts/mkimage.sh \
          --profile {{image}} \
          --outdir /out \
          --repository {{alpine_main_repo}} \
          --repository {{alpine_community_repo}}

build-image-tag:
    @echo "{{alpine_builder_tag}}"

# Run `abuild-keygen` inside build container to generate build keys
[positional-arguments]
abuild-keygen *args:
    @mkdir -p keys
    docker run --rm \
      --user $(id -u) \
      --volume $(pwd)/keys:/home/{{build_user}}/.abuild \
      $@ \
      {{alpine_builder_tag}} \
        abuild-keygen -a -i -n

# Either clone the Alpine aports git repo or update its main branch
aports-refresh:
    #!/bin/sh
    set -e
    if [ ! -e {{aports_dir}}/.git ]; then
        mkdir -p {{aports_dir}}
        git clone --shallow-since=2022-07-01 {{aports_repo}} {{aports_dir}}
    fi
    git -C {{aports_dir}} pull origin master --ff-only

# Build multi-architecture docker build image with enough dependencies to run `mkimage.sh` from aports
[positional-arguments]
build-image-build *args='--platform linux/amd64,linux/arm64,linux/arm/v6':
    docker buildx build \
      --build-arg ALPINE_VERSION={{alpine_version}} \
      --build-arg BUILD_USER={{build_user}} \
      $@ \
      -f Dockerfile.build \
      -t {{alpine_builder_tag}} \
      .

# Open shell in build image using docker
build-image-shell user=build_user platform=platform:
    @echo "Shell for platform {{platform}}..."
    docker run -it --rm \
      --platform={{platform}} \
      --volume $(pwd)/{{aports_dir}}:/aports:ro \
      --volume $(pwd)/scripts:/home/{{build_user}}/.mkimage:ro \
      --volume $(pwd)/keys:/home/{{build_user}}/.abuild:ro \
      --volume $(pwd)/overlays:/overlays:ro \
      --volume $(pwd)/out:/out \
      --user {{user}} \
      {{alpine_builder_tag}} \
        sh

[private]
shellspec-refresh:
    #!/bin/sh
    set -e
    if [ ! -e {{shellspec_dir}}/.git ]; then
        mkdir -p {{shellspec_dir}}
        git -c advice.detachedHead=false clone --depth 1 -b {{shellspec_tag}} {{shellspec_repo}} {{shellspec_dir}}
    fi

# Lint the shell scripts used to build images
lint:
    shellcheck --exclude=SC1090,SC1091 scripts/shared.sh scripts/genapkovl-*.sh

# Run unit tests of shell scripts used to build images
test: shellspec-refresh
    {{shellspec_dir}}/shellspec

ls-iso path:
    mount_dir=$(mktemp -d) \
      && sudo mount -o ro {{path}} $mount_dir && (cd $mount_dir; find . -ls) \
      ; sudo umount $mount_dir

ls-tgz path:
    tar tvzf {{path}}
