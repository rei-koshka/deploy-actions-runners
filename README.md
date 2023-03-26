# Deploy GitHub Actions Runners

## What is it

The script for a bulk deployment of GitHub Actions Runner.

It launches a specified amount of GitHub Actions runners in Docker for all repositories (of PAT holder) that has any workflows.

## Prerequisites

There is need in installing some dependencies on a host instance:

```bash
apt update && \
apt install -y curl jq && \
curl -fsSL https://get.docker.com -o get-docker.sh && \
/bin/bash ./get-docker.sh
```

## How to use

1. Clone this repository to a host instance:

   ```bash
   git clone git@github.com:Danand/deploy-actions-runners.git
   ```

2. Set executable permission for the script:

   ```bash
   chmod +x ./create-runners.sh
   ```

3. Run the script:

   ```bash
   echo "${YOUR_GITHUB_PAT_HERE}" | \
   ./create-runners.sh \
     "1" \
     "2.303.0-ubuntu-focal" \
     "unix,ubuntu,ubuntu-20.04,ubuntu-focal,debian-based,bash,apt,docker"
   ```

## Parameters

1. Quantity of runners per repository.
2. Tag of the base image (using [**github-runner**](https://hub.docker.com/r/myoung34/github-runner) by [@myoung34](https://github.com/myoung34)).
3. Comma-separated list of labels applied to each runner.
