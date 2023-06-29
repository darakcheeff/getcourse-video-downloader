#!/usr/bin/env bash
# Simple script to download videos from GetCourse.ru
# on Linux/*BSD
# Dependencies: bash, coreutils, curl

set -eu
set +f
set -o pipefail

if [ ! -f "$0" ]; then
	a0="$0"
else
	a0="bash $0"
fi

_echo_help(){
	echo "
Первым аргументом должна быть ссылка на плей-лист, найденная в исходном коде страницы сайта GetCourse.
Пример: <video id=\"vgc-player_html5_api\" data-master=\"нужная ссылка\" ... />.
Вторым аргументом должен быть путь к файлу для сохранения скачанного видео, рекомендуемое расширение — ts.
Пример: \"Как скачать видео с GetCourse.ts\"
Скопируйте ссылку и запустите скрипт, например, так:
$a0 \"эта_ссылка\" \"Как скачать видео с GetCourse.ts\"
Инструкция с графическими иллюстрациями здесь: https://github.com/mikhailnov/getcourse-video-downloader
О проблемах в работе сообщайте сюда: https://github.com/mikhailnov/getcourse-video-downloader/issues
"
}

tmpdir="/tmp/tmp_cours"
mkdir -p "$tmpdir"
trap 'rm -fr "$tmpdir"' EXIT

if [ -z "${1:-}" ] || \
   [ -z "${2:-}" ] || \
   [ -n "${3:-}" ]; then
	_echo_help
	exit 1
fi

URL="$1"
result_file="$2"

main_playlist="$tmpdir/main_playlist"
curl -L --output "$main_playlist" "$URL"

second_playlist="$tmpdir/second_playlist"
if grep -qE '^https?:\/\/.*\.ts' "$main_playlist"; then
	cp "$main_playlist" "$second_playlist"
else
	tail="$(tail -n1 "$main_playlist")"
	if ! [[ "$tail" =~ ^https?:// ]]; then
		echo "В содержимом заданной ссылки нет прямых ссылок на файлы *.ts (первый вариант),"
		echo "также последняя строка в ней не содержит ссылки на другой плей-лист (второй вариант)."
		echo "Либо указана неправильная ссылка, либо GetCourse изменил алгоритмы."
		echo "Если уверены, что дело в изменившихся алгоритмах GetCourse, опишите проблему здесь:"
		echo "https://github.com/mikhailnov/getcourse-video-downloader/issues (на русском)."
		exit 1
	fi
	curl -L --output "$second_playlist" "$tail"
fi

c=0
while read -r line; do
	if ! [[ "$line" =~ ^http ]]; then continue; fi
	filename="$(printf '%05d' "$c").ts"
	if [ -f "$tmpdir/$filename" ]; then
		echo "Файл $filename уже существует. Пропускаю скачивание."
	else
		while true; do
			if curl -L --output "$tmpdir/$filename" "$line"; then
				break
			else
				echo "Ошибка при скачивании файла $filename. Повторная попытка..."
			fi
		done
	fi
	c=$((++c))
done < "$second_playlist"

cat "$tmpdir"/*.ts > "$result_file"
echo "Скачивание завершено. Результат здесь: $result_file"

rm -fr "$tmpdir"
