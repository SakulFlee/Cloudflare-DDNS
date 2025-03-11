ARG BASE_IMAGE=alpine
ARG BASE_IMAGE_VERSION=latest

FROM ${BASE_IMAGE}:${BASE_IMAGE_VERSION}

RUN apk update && \
    apk add bash jq sed curl

COPY cf_ddns.sh /opt/cf_ddns/cf_ddns.sh
RUN chmod +x /opt/cf_ddns/cf_ddns.sh

CMD [ "/bin/bash", "/opt/cf_ddns/cf_ddns.sh" ]
