# Build patched loxilb eBPF objects for Armbian (with configurable MAX_REAL_CPUS)
# Based on official loxilb Dockerfile: https://github.com/loxilb-io/loxilb/blob/v0.9.8.4/Dockerfile

ARG TAG=v0.9.8.4
ARG MAX_REAL_CPUS=4

FROM ubuntu:22.04 AS build

ARG DEBIAN_FRONTEND=noninteractive
ARG TAG
ARG MAX_REAL_CPUS

# Install minimal build dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    wget \
    git \
    clang \
    llvm \
    libelf-dev \
    build-essential \
    pkg-config \
    libssl-dev \
    zlib1g-dev \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Install bpftool (needed for eBPF build)
RUN wget https://github.com/libbpf/bpftool/releases/download/v7.2.0/bpftool-libbpf-v7.2.0-sources.tar.gz && \
    tar -xvzf bpftool-libbpf-v7.2.0-sources.tar.gz && \
    cd bpftool/src/ && \
    make clean && make -j $(nproc) && \
    cp -f ./bpftool /usr/local/sbin/bpftool && \
    cd ../.. && rm -fr bpftool*

# Clone loxilb with submodules
RUN git clone --recurse-submodules --branch $TAG https://github.com/loxilb-io/loxilb /root/loxilb-io/loxilb/

# Patch loxilb-ebpf to use configurable MAX_REAL_CPUS
WORKDIR /root/loxilb-io/loxilb/loxilb-ebpf
RUN sed -i "s/MAX_REAL_CPUS=16/MAX_REAL_CPUS=${MAX_REAL_CPUS}/g" common/common.mk && \
    echo "=== Patched common.mk ===" && grep "MAX_REAL_CPUS" common/common.mk

# Build libbpf first (required dependency)
RUN cd /root/loxilb-io/loxilb/loxilb-ebpf/libbpf/src && \
    make clean && make -j$(nproc) && make install

# Build only the eBPF kernel objects (not the userspace library)
WORKDIR /root/loxilb-io/loxilb/loxilb-ebpf/kernel
RUN make clean && \
    make llb_xdp_main.o llb_ebpf_main.o llb_ebpf_emain.o llb_kern_sock.o llb_kern_sockstream.o llb_kern_sockdirect.o

# Strip BTF information from eBPF objects to avoid kernel BTF validation issues
RUN for obj in llb_xdp_main.o llb_ebpf_main.o llb_ebpf_emain.o llb_kern_sock.o llb_kern_sockstream.o llb_kern_sockdirect.o; do \
        echo "Stripping BTF from $obj"; \
        llvm-strip --strip-debug "$obj" || true; \
    done
    
# Verify the built eBPF objects
RUN ls -lh /root/loxilb-io/loxilb/loxilb-ebpf/kernel/*.o

# Stage 2: Use official loxilb image and replace only the eBPF objects
ARG TAG
FROM ghcr.io/loxilb-io/loxilb:${TAG}

# Re-declare ARG after FROM to make it available in this stage
ARG MAX_REAL_CPUS

# Replace eBPF objects with our patched versions (MAX_REAL_CPUS=${MAX_REAL_CPUS})
COPY --from=build /root/loxilb-io/loxilb/loxilb-ebpf/kernel/llb_xdp_main.o /opt/loxilb/llb_xdp_main.o
COPY --from=build /root/loxilb-io/loxilb/loxilb-ebpf/kernel/llb_ebpf_main.o /opt/loxilb/llb_ebpf_main.o
COPY --from=build /root/loxilb-io/loxilb/loxilb-ebpf/kernel/llb_ebpf_emain.o /opt/loxilb/llb_ebpf_emain.o

# Verify replacement
RUN echo "=== Patched eBPF objects installed ===" && ls -lh /opt/loxilb/*.o

# Keep the same entrypoint as official image
# ENTRYPOINT is inherited from base image
