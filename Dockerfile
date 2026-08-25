FROM python:3.11-slim

ARG EUKDETECT_VERSION=v2.0.2
ARG DOWNLOAD_DATABASE=0

LABEL maintainer="Jason Stajich <jasonstajich.phd@gmail.com>"
LABEL description="EukDetect: Detect eukaryotes from shotgun metagenomic data"
LABEL version="${EUKDETECT_VERSION}"

WORKDIR /opt/eukdetect

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install uv package manager for efficient dependency management
ENV PATH="/root/.local/bin:$PATH"
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

COPY . .

RUN uv pip install --system -e . && \
    eukdetect --version && \
    uvx --version

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

ENTRYPOINT ["eukdetect"]
CMD ["--help"]
