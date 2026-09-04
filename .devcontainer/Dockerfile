FROM node:24-bookworm

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git \
        curl \
        ca-certificates \
        bash \
        nano \
        less \
        procps \
        iproute2 \
    && rm -rf /var/lib/apt/lists/*

# Claude Code
RUN curl -fsSL https://opencode.ai/install | su - node -s /bin/bash

WORKDIR /workspace

CMD ["sleep", "infinity"]
