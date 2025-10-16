# Stage 1: Build patched eBPF objects
FROM ubuntu:22.04 as builder

# Install ALL dependencies for loxilb-ebpf build
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    git \
    clang-14 \
    llvm-14 \
    make \
    gcc-arm-linux-gnueabihf \
    pkg-config \
    libelf-dev \
    zlib1g-dev \
    libbpf-dev \
    libssl-dev \
    m4 \
    linux-headers-generic \
    linux-tools-generic \
    linux-tools-common \
    libpcap-dev \
    elfutils \
    dwarves \

    && rm -rf /var/lib/apt/lists/*

# Create bpftool symlink (linux-tools-generic installs it in a versioned directory)
RUN ln -s /usr/lib/linux-tools/*/bpftool /usr/local/bin/bpftool || \
    ln -s /usr/sbin/bpftool /usr/local/bin/bpftool || true

# Verify tools are available
RUN which clang && which llc && which bpftool && bpftool version

# Clone main loxilb repo
WORKDIR /build
RUN git clone --depth 1 --branch v0.9.8.4 https://github.com/loxilb-io/loxilb.git

# Initialize and clone the loxilb-ebpf submodule
WORKDIR /build/loxilb
RUN git submodule update --init --recursive

# Verify submodule structure
RUN ls -la loxilb-ebpf/common/ && ls -la loxilb-ebpf/kernel/

# Patch common/common.mk to hardcode MAX_REAL_CPUS=4
WORKDIR /build/loxilb/loxilb-ebpf
RUN sed -i 's/MAX_REAL_CPUS=16/MAX_REAL_CPUS=4/g' common/common.mk

# Show the bpftool line to understand its format
RUN echo "=== Looking for bpftool command ===" && grep -n "bpftool" common/common.mk || echo "No bpftool in common.mk, checking elsewhere..."

# Verify the MAX_REAL_CPUS patch was applied
RUN echo "=== Patched common.mk ===" && grep "MAX_REAL_CPUS" common/common.mk

# Build the eBPF objects from the kernel directory
WORKDIR /build/loxilb/loxilb-ebpf/kernel

# Now build - if it tries to regenerate vmlinux.h, our empty file will be overwritten
# but if it fails, we have a fallback
RUN make clean && make

# Verify the built objects exist
RUN echo "=== Built eBPF objects ===" && ls -lh *.o

# Stage 2: Inject patched objects into official loxilb image
FROM ghcr.io/loxilb-io/loxilb:v0.9.8.4

# Replace the XDP object with our patched version (4 CPUs instead of 16)
COPY --from=builder /build/loxilb/loxilb-ebpf/kernel/llb_xdp_main.o /opt/loxilb/llb_xdp_main.o

# Also replace TC BPF objects to ensure consistency
COPY --from=builder /build/loxilb/loxilb-ebpf/kernel/llb_ebpf_main.o /opt/loxilb/llb_ebpf_main.o
COPY --from=builder /build/loxilb/loxilb-ebpf/kernel/llb_ebpf_emain.o /opt/loxilb/llb_ebpf_emain.o

# Verify the files were replaced
RUN echo "=== Installed patched eBPF objects ===" && ls -lh /opt/loxilb/*.o
