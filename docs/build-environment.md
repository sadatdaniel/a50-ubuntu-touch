# The build environment

How this port is built, reproduced from the UBports porting guide's own
instructions. The guide ("Setting up", Ubuntu 20.04-or-newer section) does not
prescribe a Docker image — it prescribes an Ubuntu host with an apt list, and
that is what the container below is.

## The container

Windows cannot host the kernel tree itself (`aux.c` is a reserved DOS device
name — git refuses the checkout, measured 2026-09-01), so the build runs in
Docker:

```sh
docker run -d --name ut-build-env ubuntu:22.04 sleep infinity
docker exec ut-build-env bash -c 'apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    git gnupg flex bison gperf build-essential zip bzr curl libc6-dev \
    x11proto-core-dev libgl1-mesa-dev libxml2-utils xsltproc zlib1g-dev \
    schedtool liblz4-tool bc lzop imagemagick libncurses5 rsync \
    python3 python-is-python3 cpio xz-utils'
```

`sleep infinity` is deliberate: a container whose entrypoint is a build
script re-runs the whole build on every `docker start` and races any
interactive work (that cost the previous session a suspect defconfig — see
`docs/experiments/002-bare-make-config.md`).

## Deviations from the guide's list, and why

The guide's Ubuntu list includes several `:i386` multilib packages
(`libncurses5-dev:i386`, `libx11-dev:i386`, `libreadline6-dev:i386`,
`libgl1-mesa-glx:i386`, `zlib1g-dev:i386`, `g++-multilib`,
`mingw-w64-i686-dev`) plus `python2` and `repo`. Those serve the old
full-system H9 build. This port uses the **standalone kernel method** (see
[`conventions.md`](conventions.md)), whose only host-side compiled pieces are
the kernel's own host tools and the Python 3 `mkbootimg` — neither needs
32-bit headers. `libreadline6-dev` and `libgl1-mesa-glx` no longer exist in
22.04 under those names. `cpio` and `xz-utils` are added because
`make-bootimage.sh` shells out to them. If a later stage (rootfs, tarball)
turns out to need more, add it here and note it — do not silently sprinkle
packages into ad-hoc `docker exec` calls.

## Running a build

```sh
docker exec ut-build-env bash -c '
    rm -rf /root/ut-port /root/ut-build /root/ut-out &&
    git clone https://github.com/sadatdaniel/a50-ubuntu-touch /root/ut-port &&
    cd /root/ut-port && bash build.sh -k -b /root/ut-build -o /root/ut-out'
```

* Always clone from the published repo — the build must work from what is on
  GitHub, not from local state.
* `-k` stops after the boot image (kernel + ramdisk), skipping the rootfs and
  tarball stages — use it while the kernel is the thing under test.
* Bind mounts are not used: on Windows Docker Desktop the container side of
  `-v` is silently mangled (known trap, see a50-halium's
  `docs/starting-a-new-port.md` §3). Artifacts come out with `docker cp`.

## What the toolchain actually is

The tools fetch Google's prebuilt Clang (`android11-gsi` branch,
`clang-r383902`, clang 11) — **not** the Proton Clang 210521 that every
booting A50 kernel was built with. That is kernel.md risk 3 and stays a
separate variable for the first boot test. `deviceinfo_kernel_llvm_compile`
is set because the config carries `CONFIG_LTO_CLANG=y` + `CONFIG_THINLTO=y`,
which requires `ld.lld` and the LLVM binutils (see the deviceinfo comment).
