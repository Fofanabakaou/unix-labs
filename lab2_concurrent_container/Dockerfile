# Образ для конкурентного управления файлами
FROM debian:bookworm-slim

# В Debian утилита flock входит в пакет util-linux (уже установлен),
# а /bin/sh — это dash, совместимый с POSIX Shell.
COPY worker.sh /usr/local/bin/worker.sh
RUN chmod +x /usr/local/bin/worker.sh

ENV SHARED_DIR=/data
ENTRYPOINT ["/usr/local/bin/worker.sh"]
