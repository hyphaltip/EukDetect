FROM python:3.11-slim

ARG EUKDETECT_VERSION=v2.0.2
ARG DOWNLOAD_DATABASE=0

LABEL maintainer="Jason Stajich <jasonstajich.phd@gmail.com>"
LABEL description="EukDetect: Detect eukaryotes from shotgun metagenomic data"
LABEL version="${EUKDETECT_VERSION}"

WORKDIR /opt/eukdetect

# Runtime aligners. EukDetect's snakemake `runaln` rule shells out to bowtie2 and
# samtools, so they must be IN the image -- a container has its own filesystem and
# cannot see host modules. Debian 13 (trixie, the python:3.11-slim base) ships
# samtools 1.21, which is current, so it is kept from apt. bowtie2 is built from
# source below instead of using the apt package -- see that step for why.
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    build-essential \
    samtools \
    && rm -rf /var/lib/apt/lists/*

# Build bowtie2 from source instead of using the apt/conda package. Distro
# packages ship only a single baseline (SSE2) binary with no -v256 (AVX2 /
# x86-64-v3) variant, so they silently miss the AVX2 speedup on any CPU that
# supports it. Building from source with the container's own toolchain (GCC
# 12+, needed for -march=x86-64-v3 dispatch) produces the -v256 binaries and
# the runtime-dispatch launcher that picks them automatically. Mirrors the
# approach used in the AAFTF and funannotate Dockerfiles.
ARG BOWTIE2_VERSION=2.5.5
RUN git clone --depth 1 --branch "v${BOWTIE2_VERSION}" \
      https://github.com/BenLangmead/bowtie2.git /tmp/bowtie2-src && \
    make -C /tmp/bowtie2-src -j"$(nproc)" && \
    make -C /tmp/bowtie2-src install PREFIX=/usr/local && \
    rm -rf /tmp/bowtie2-src

# Install uv package manager for efficient dependency management
ENV PATH="/root/.local/bin:$PATH"
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

COPY . .

RUN uv pip install --system -e . && \
    eukdetect --version && \
    uvx --version && \
    bowtie2 --version | head -1 && \
    samtools --version | head -1

# Create database directory
RUN mkdir -p /opt/eukdb

# Optional: Download EukDetect database from Zenodo (record 19056625)
# Database files total ~7.1 GB
# To build with database included: docker build --build-arg DOWNLOAD_DATABASE=1 .
RUN if [ "$DOWNLOAD_DATABASE" = "1" ]; then \
      cd /opt/eukdb && \
      uvx zenodo_get 19056625; \
    fi

ENV EUKDETECT_DB="/opt/eukdb"


# Container hygiene for HPC / Singularity / Apptainer use:
#  - snakemake writes a source cache to $XDG_CACHE_HOME, else $HOME/.cache. Under
#    apptainer $HOME is often absent or read-only, which fails the run with
#    FileNotFoundError on <home>/.cache/snakemake. Default it somewhere writable.
#  - bowtie2's perl wrapper emits locale warnings on every invocation without these.
ENV XDG_CACHE_HOME=/tmp/.cache \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

ENTRYPOINT ["eukdetect"]
CMD ["--help"]
