# EukDetect Docker Images

A Docker image is automatically built and published to GitHub Container Registry.

## Image Overview

- **Current Version**: `v2.0.2`
- **Tag**: `ghcr.io/hyphaltip/eukdetect:v2.0.2` (or `:latest`)
- **Size**: ~500 MB (EukDetect + dependencies, no database)
- **Database**: Downloaded on-demand by the user (7.1 GB from Zenodo 19056625)
- **Package Manager**: `uv` + `uvx` included for running tools without installation
- **Environment variable**: `$EUKDETECT_DB=/opt/eukdb` (ready for mounting)

## Using `uvx` to Download Zenodo Database

The image includes `uv` and `uvx`, which allows you to run Python tools without installing them. To download the EukDetect database from Zenodo:

```bash
# Run uvx inside the container to download the database
docker run -v /path/to/eukdb:/opt/eukdb \
  ghcr.io/hyphaltip/eukdetect:v2.0.2 \
  uvx zenodo_get 19056625
```

**What `uvx zenodo_get 19056625` does:**
- Downloads all files from Zenodo record 19056625 (the EukDetect v2 database)
- Requires internet connection inside the container
- Takes ~30 minutes on a typical internet connection
- Requires ~7.1 GB free disk space in the mounted volume
- Downloads: marker gene database, bowtie2 indices, taxonomy data, and pre-built ETE3 sqlite database

**Note:** The database download happens only once. After downloading, the database directory can be mounted read-only in subsequent analyses.

## Usage Examples

### Option 1: Mount an existing database from host
If you already have the database on your host machine:

```bash
docker run -v /path/to/eukdb:/opt/eukdb \
  ghcr.io/hyphaltip/eukdetect:v2.0.2 single \
  -1 sample_R1.fastq.gz \
  -2 sample_R2.fastq.gz \
  -n sample_name \
  --outdir results/ \
  --database /opt/eukdb \
  --cores 16
```

### Option 2: Download database inside container on first run
Download the database (one-time operation):

```bash
docker run -v /path/to/eukdb:/opt/eukdb \
  ghcr.io/hyphaltip/eukdetect:v2.0.2 \
  uvx zenodo_get 19056625
```

Then run analysis with the downloaded database:

```bash
docker run -v /path/to/eukdb:/opt/eukdb \
  ghcr.io/hyphaltip/eukdetect:v2.0.2 single \
  -1 sample_R1.fastq.gz \
  -2 sample_R2.fastq.gz \
  -n sample_name \
  --outdir results/ \
  --database /opt/eukdb \
  --cores 16
```

### Option 3: Interactive shell to download or inspect database
For interactive work or troubleshooting:

```bash
docker run -it -v /path/to/eukdb:/opt/eukdb \
  ghcr.io/hyphaltip/eukdetect:v2.0.2 \
  bash

# Inside container shell:
cd /opt/eukdb
uvx zenodo_get 19056625
ls -lh  # Verify downloaded files
```

## Available Tags

### For Pushes to `master`/`main`
- `latest` - Latest build from master/main
- `master` - Branch-specific tag
- `main` - Branch-specific tag (if pushing to main)

### For Releases
- `v2.0.2` - Full version tag (current)
- `2.0.2` - Version without 'v' prefix (current)
- Previous releases available with their respective tags

## Image Contents

- Python 3.11 slim base
- `uv` package manager and `uvx` (for efficient package management)
- EukDetect package (from current source)
- `zenodo_get` available via `uvx` (no installation needed)
- `/opt/eukdb` directory prepared for database mounting

## Building Locally

### Build default image
```bash
docker build -t eukdetect:local .
```

### Build with a specific version
```bash
docker build -t eukdetect:v2.0.2 \
  --build-arg EUKDETECT_VERSION=v2.0.2 .
```

### Build and include database (not recommended - creates ~7.5 GB image)
```bash
docker build -t eukdetect:local-with-db \
  --build-arg DOWNLOAD_DATABASE=1 .
```

**Note:** The workflow normally builds with `DOWNLOAD_DATABASE=0` to keep images small. Users download the database themselves using `uvx zenodo_get 19056625`.

## Notes

- All images are signed with Cosign (Sigstore keyless signing)
- SLSA v1 provenance attestations are generated for each build
- Images are built and cached via GitHub Actions
- Docker layers are cached between builds for faster rebuilds

## Authentication

Images are public and don't require authentication. For unauthenticated pulls:

```bash
docker pull ghcr.io/hyphaltip/eukdetect:latest
```

## Troubleshooting

### Database download fails in container
If `uvx zenodo_get` fails inside a container:
- Ensure the container has internet access
- Ensure sufficient disk space (7.1 GB required)
- Check the mounted volume has write permissions
- Try downloading on the host machine instead and mounting the directory

### Mount permissions
If you encounter permission issues when mounting volumes:
```bash
docker run -u $(id -u):$(id -g) -v /path/to/eukdb:/opt/eukdb ...
```

### Using with Singularity/Apptainer
Convert the OCI image to Singularity format:
```bash
singularity pull eukdetect.sif docker://ghcr.io/hyphaltip/eukdetect:v2.0.2
singularity exec eukdetect.sif eukdetect --help
```

### Running analysis with mounted inputs and outputs
Mount read-only volumes for inputs and database, write-only for results:

```bash
docker run \
  -v /path/to/reads:/data:ro \
  -v /path/to/eukdb:/opt/eukdb:ro \
  -v /path/to/results:/results \
  ghcr.io/hyphaltip/eukdetect:v2.0.2 single \
  -1 /data/sample_R1.fastq.gz \
  -2 /data/sample_R2.fastq.gz \
  -n sample_name \
  --outdir /results \
  --database /opt/eukdb \
  --cores 16
```

### Downloading zenodo database during container build
To create a custom image with the database pre-downloaded:

```bash
docker build -t eukdetect:v2.0.2-with-db \
  --build-arg EUKDETECT_VERSION=v2.0.2 \
  --build-arg DOWNLOAD_DATABASE=1 .

# Use the image (database already present)
docker run eukdetect:v2.0.2-with-db single \
  -1 sample_R1.fastq.gz \
  -2 sample_R2.fastq.gz \
  -n sample_name \
  --database /opt/eukdb
```
