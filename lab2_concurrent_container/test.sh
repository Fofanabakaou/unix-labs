#!/bin/sh
# Тест: запустить N контейнеров на общем томе, подождать T секунд,
# проверить отсутствие гонок, остановить и удалить контейнеры.
# Использование: ./test.sh N [T]     например: ./test.sh 50 30

N=${1:-1}
T=${2:-20}
IMAGE=concurrent-files
VOLUME=shared-data
LABEL=lab2-test

set -e
docker build -t "$IMAGE" .
docker volume create "$VOLUME" > /dev/null

echo "Запуск $N контейнеров..."
i=1
while [ "$i" -le "$N" ]; do
    docker run -d --label "$LABEL" -v "$VOLUME":/data "$IMAGE" > /dev/null
    i=$((i + 1))
done

echo "Ожидание $T секунд..."
sleep "$T"

echo "Файлы в общем томе сейчас:"
docker run --rm -v "$VOLUME":/data --entrypoint sh "$IMAGE" \
    -c 'cd /data && for f in [0-9]*; do [ -e "$f" ] && printf "%s: %s\n" "$f" "$(cat "$f")"; done; true'

ids=$(docker ps -q --filter "label=$LABEL")
created=0
races=0
for c in $ids; do
    n=$(docker logs "$c" 2>/dev/null | grep -c 'создан' || true)
    r=$(docker logs "$c" 2>&1 | grep -c 'RACE' || true)
    created=$((created + n))
    races=$((races + r))
done

echo "Контейнеров: $N, создано файлов всего: $created, гонок (RACE): $races"

echo "Остановка контейнеров..."
docker stop $ids > /dev/null
docker rm $ids > /dev/null

if [ "$races" -eq 0 ]; then
    echo "РЕЗУЛЬТАТ: гонок нет, работа стабильна"
else
    echo "РЕЗУЛЬТАТ: обнаружены гонки!"
    exit 1
fi
