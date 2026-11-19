#!/bin/sh
# Скрипт сборки исходного файла (C, C++ или TeX).
# Имя конечного файла берётся из комментария вида  Output: имя_файла
#
# Коды возврата:
#   0 - сборка выполнена успешно
#   1 - неверный вызов (нет аргумента)
#   2 - исходный файл не найден или недоступен для чтения
#   3 - в файле нет комментария Output: или имя некорректно
#   4 - неподдерживаемый тип файла
#   5 - не удалось создать временный каталог
#   6 - ошибка компиляции
#   7 - не удалось поместить результат рядом с исходным файлом
#   128+N - работа прервана сигналом N

# --- 1. Удаление временного каталога при любом завершении ---
tmpdir=""

cleanup() {
    rc=$?
    trap - EXIT
    if [ -n "$tmpdir" ]; then
        rm -rf -- "$tmpdir"
    fi
    exit "$rc"
}

trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 131' QUIT
trap 'exit 141' PIPE
trap 'exit 143' TERM

# --- 2. Проверка аргумента ---
if [ "$#" -ne 1 ]; then
    echo "Использование: $0 <исходный_файл>" >&2
    exit 1
fi

src=$1

if [ ! -f "$src" ] || [ ! -r "$src" ]; then
    echo "Ошибка: файл '$src' не найден или недоступен для чтения" >&2
    exit 2
fi

# --- 3. Поиск комментария Output: ---
output=$(sed -n 's/.*Output:[[:space:]]*\([^[:space:]]*\).*/\1/p' "$src" | head -n 1)

if [ -z "$output" ]; then
    echo "Ошибка: в файле '$src' нет комментария 'Output: <имя>'" >&2
    exit 3
fi

case "$output" in
    */*)
        echo "Ошибка: имя '$output' не должно содержать '/'" >&2
        exit 3
        ;;
esac

# Каталог исходного файла и абсолютный путь к нему
srcdir=$(cd "$(dirname -- "$src")" && pwd)
srcname=$(basename -- "$src")

# --- 4. Создание временного каталога ---
tmpdir=$(mktemp -d) || {
    echo "Ошибка: не удалось создать временный каталог" >&2
    exit 5
}

# --- 5. Сборка в зависимости от типа файла ---
case "$srcname" in
    *.c)
        ${CC:-cc} -Wall -O2 -o "$tmpdir/$output" "$srcdir/$srcname" || {
            echo "Ошибка: компиляция C завершилась неудачно" >&2
            exit 6
        }
        result="$tmpdir/$output"
        ;;
    *.cpp|*.cc|*.cxx)
        ${CXX:-c++} -Wall -O2 -o "$tmpdir/$output" "$srcdir/$srcname" || {
            echo "Ошибка: компиляция C++ завершилась неудачно" >&2
            exit 6
        }
        result="$tmpdir/$output"
        ;;
    *.tex)
        jobname=${srcname%.tex}
        (cd "$srcdir" && pdflatex -interaction=nonstopmode -halt-on-error \
            -output-directory "$tmpdir" "$srcname") > "$tmpdir/build.log" 2>&1 || {
            echo "Ошибка: сборка TeX завершилась неудачно (журнал ниже)" >&2
            tail -n 20 "$tmpdir/build.log" >&2
            exit 6
        }
        result="$tmpdir/$jobname.pdf"
        ;;
    *)
        echo "Ошибка: неподдерживаемый тип файла '$srcname'" >&2
        exit 4
        ;;
esac

# --- 6. Перенос результата рядом с исходным файлом ---
cp -- "$result" "$srcdir/$output" || {
    echo "Ошибка: не удалось записать '$srcdir/$output'" >&2
    exit 7
}

echo "Готово: $srcdir/$output"
exit 0
