FROM debian:bookworm-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends procps python3 taskwarrior tasksh timewarrior tmux \
    && rm -rf /var/lib/apt/lists/*
COPY --chmod=0755 cronicle /usr/local/bin/cronicle
ENV HOME=/data LANG=C.UTF-8
WORKDIR /data
VOLUME ["/data"]
ENTRYPOINT ["cronicle"]
