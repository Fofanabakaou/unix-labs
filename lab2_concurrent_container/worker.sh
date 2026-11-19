#!/bin/sh
# Конкурентное управление файлами в общем каталоге.
# В бесконечном цикле: создать файл -> пауза 1 с -> удалить файл -> пауза 1 с.

DIR=${SHARED_DIR:-/data}       # каталог общего тома
LOCK="$DIR/.lock"              # служебный файл синхронизации

# Случайный идентификатор контейнера (один и тот же для всех его файлов)
ID=$(od -An -N4 -tx4 /dev/urandom | tr -d ' \n')

count=0          # сколько файлов создал этот контейнер
current=""       # файл, созданный последним

# При остановке контейнера (docker stop -> SIGTERM) удалить свой файл
cleanup() {
    [ -n "$current" ] && rm -f -- "$DIR/$current"
    exit 0
}
trap cleanup INT TERM

mkdir -p "$DIR"
echo "Контейнер $ID запущен, каталог $DIR"

while true; do
    count=$((count + 1))

    # --- Атомарная операция: поиск свободного имени и создание файла ---
    current=$(
        {
            flock -x 9
            i=1
            while :; do
                name=$(printf '%03d' "$i")
                [ -e "$DIR/$name" ] || break
                i=$((i + 1))
            done
            # set -C запрещает перезапись: если имя уже занято (гонка), будет ошибка
            ( set -C; : > "$DIR/$name" ) 2>/dev/null || name="RACE:$name"
            echo "$name"
        } 9>"$LOCK"
    )
    # --- Конец атомарной операции (блокировка снята) ---

    case "$current" in
        RACE:*)
            echo "RACE CONDITION: файл ${current#RACE:} уже существовал!" >&2
            current=""
            continue
            ;;
    esac

    # Запись данных уже вне блокировки: имя файла принадлежит только нам
    printf '%s %d\n' "$ID" "$count" > "$DIR/$current"
    echo "$ID: создан $current (№ $count)"

    sleep 1

    rm -f -- "$DIR/$current"
    echo "$ID: удалён $current"
    current=""

    sleep 1
done
