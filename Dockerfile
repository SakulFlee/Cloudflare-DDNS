ARG BASE_IMAGE=debian
ARG BASE_IMAGE_VERSION=latest

FROM ${BASE_IMAGE}:${BASE_IMAGE_VERSION}

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y bash jq sed dnsutils curl

COPY cf_ddns.sh /cf_ddns.sh

ENTRYPOINT [ "bash /cf_ddns.sh" ]
