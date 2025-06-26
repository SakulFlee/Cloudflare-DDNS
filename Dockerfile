ARG BASE_IMAGE=alpine
ARG BASE_IMAGE_VERSION=latest

FROM ${BASE_IMAGE}:${BASE_IMAGE_VERSION}

RUN if [ -f /etc/alpine-release ]; then \
        apk update && \
        apk add --no-cache bash jq sed curl; \
    elif [ -f /etc/debian_version ]; then \
        apt-get update && \
        apt-get install -y bash jq sed curl && \
        rm -rf /var/lib/apt/lists/*; \
    else \
        echo "Unsupported base image"; \
        exit -1; \
    fi

COPY cf_ddns.sh /cf_ddns.sh
RUN chmod +x /cf_ddns.sh

CMD [ "/bin/bash", "/cf_ddns.sh" ]
