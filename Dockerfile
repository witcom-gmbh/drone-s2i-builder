FROM plugins/docker

ENV S2I_VERSION=1.3.1 \
    S2I_GITCOMMIT=a5a77147
RUN set -xe; \
    wget -O - https://github.com/openshift/source-to-image/releases/download/v${S2I_VERSION}/source-to-image-v${S2I_VERSION}-${S2I_GITCOMMIT}-linux-amd64.tar.gz | tar -C /usr/local/bin -zxf - ./s2i

RUN set -xe; \
    apk add --no-cache netcat-openbsd bash;\
    apk upgrade --no-cache musl

ADD s2ibuild.sh /usr/local/bin/s2ibuild.sh
LABEL maintainer="Carsten Buchberger <c.buchberger@witcom.de>"

ENTRYPOINT ["/usr/local/bin/dockerd-entrypoint.sh", "/usr/local/bin/s2ibuild.sh"]
