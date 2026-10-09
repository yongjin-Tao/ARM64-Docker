FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
        ca-certificates \
        curl \
        default-mysql-client \
    && rm -rf /var/lib/apt/lists/*

CMD ["bash"]
