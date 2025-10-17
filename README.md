# loxilb-arm-fix

Patched loxilb Docker images for ARM devices with limited CPU cores.

## The Problem

The official loxilb eBPF objects are compiled with `MAX_REAL_CPUS=16`, which causes failures on ARM devices with fewer CPU cores. On devices like the Radxa Zero and similar single-board computers, this prevents loxilb from starting.

### Error Symptoms

If you're running into this issue, you'll see errors like:

```text
libbpf: Kernel error message: Invalid handle
08:15:31 ERROR common_libbpf.c:94: tc: bpf hook destroy failed for llb0:0
08:15:31 DEBUG loxilb_libdp.c:3506: /opt/loxilb/llb_xdp_main.o: nr 0 psection xdp_packet_hook
libbpf: map 'cpu_map': failed to create: Argument list too long(-7)
libbpf: failed to load object '/opt/loxilb/llb_xdp_main.o'
08:15:31 ERROR common_libbpf.c:350: bpfhelper: loading BPF-OBJ file(/opt/loxilb/llb_xdp_main.o) : Argument list too long
08:15:31 ERROR common_libbpf.c:368: bpfhelper: loading file: /opt/loxilb/llb_xdp_main.o failed
loxilb: loxilb_libdp.c:1576: llb_xh_init: Assertion `0' failed.
SIGABRT: abort
```

The root cause is that the eBPF objects are compiled with `MAX_REAL_CPUS=16`. Setting this value to match your device's actual CPU count resolves the issue.

## The Solution

Pre-built loxilb Docker images with eBPF objects compiled for specific CPU counts (2, 4, and 8). These are identical to official loxilb releases except for the `MAX_REAL_CPUS` setting.

## Available Images

All images are available at [GitHub Container Registry](https://github.com/ilmax/loxilb-arm-fix/pkgs/container/loxilb):

```bash
# For 2-core devices
docker pull ghcr.io/ilmax/loxilb:latest-cpu2

# For 4-core devices (e.g., Radxa Zero)
docker pull ghcr.io/ilmax/loxilb:latest-cpu4

# For 8-core devices
docker pull ghcr.io/ilmax/loxilb:latest-cpu8
```

Tagged versions matching upstream releases are also available:

```bash
docker pull ghcr.io/ilmax/loxilb:v0.9.8.4-cpu4
```

## Usage

Replace the official loxilb image with the appropriate CPU variant:

```yaml
# docker-compose.yml
services:
  loxilb:
    image: ghcr.io/ilmax/loxilb:latest-cpu4
    # ... rest of your configuration
```

## How It Works

The repository automatically:

1. Checks for new loxilb releases nightly
2. Builds eBPF objects with the appropriate `MAX_REAL_CPUS` value
3. Creates Docker images for linux/arm64
4. Publishes with proper versioning and CPU variant tags

Only the eBPF kernel objects are recompiled - all userspace components are identical to the official release.

## Supported Devices

Tested on:

- Radxa Zero 3E (4 cores)

Should work on other ARM SBCs with 2-8 CPU cores.

## License

This project follows the same license as loxilb. See [LICENSE](LICENSE) for details.
