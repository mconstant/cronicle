FROM debian:bookworm-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       -o 'DPkg::Options::=--path-include=/usr/share/doc/timewarrior*' \
       procps python3 taskwarrior tasksh timewarrior tmux \
    && rm -rf /var/lib/apt/lists/*
COPY --chmod=0755 cronicle /usr/local/bin/cronicle
COPY ledger.py /usr/local/lib/cronicle/ledger.py
ENV HOME=/data LANG=C.UTF-8
WORKDIR /data
VOLUME ["/data"]
ENTRYPOINT ["cronicle"]
