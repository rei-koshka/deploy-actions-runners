FROM myoung34/github-runner:${BASE_IMAGE_VERSION} as github-actions-runner

RUN apt update && \
    apt install -y \
    bsdmainutils \
    jq \
    htop \
    iftop

FROM github-actions-runner
