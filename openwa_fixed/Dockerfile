ARG BUILD_FROM=ghcr.io/rmyndharis/openwa:latest
FROM ${BUILD_FROM}

USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      python3 \
      ca-certificates \
      curl \
      procps \
    && rm -rf /var/lib/apt/lists/*

COPY run.sh /run.sh
COPY helper_server.py /usr/local/bin/helper_server.py

RUN chmod a+x /run.sh \
    && chmod a+x /usr/local/bin/helper_server.py

CMD ["/run.sh"]
