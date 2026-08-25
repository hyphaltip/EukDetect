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
# bowtie2 2.5.4 and samtools 1.21, both current; note Ubuntu 24.04 would give an
# OLDER samtools (1.19.x), so there is no reason to change base.
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    bowtie2 \
    samtools \
    && rm -rf /var/lib/apt/lists/*

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
