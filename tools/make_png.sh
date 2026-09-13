#!/bin/sh
# make_png.sh - assemble PNG from raw scanlines using gzip-compressed IDAT
# usage: make_png.sh raw.bin WIDTH HEIGHT out.png
set -e
export LC_ALL=C LANG=C
RAW="$1"; W="$2"; H="$3"; OUT="$4"
T=/data/data/com.termux/files/home/.cache/opencode/tmp/pngfix
mkdir -p "$T"
AWKDIR="$(dirname "$0")"
# 1. adler of raw
od -A n -t u1 "$RAW" | gawk -f "$AWKDIR/adler32.awk" > "$T/adler.bin"
# 2. gzip raw, strip header(10)/footer(8) -> deflate payload
gzip -n -9 -c "$RAW" > "$T/raw.gz"
SZ=$(wc -c < "$T/raw.gz")
PAYLOAD=$((SZ - 18))
dd if="$T/raw.gz" of="$T/deflate.bin" bs=1 skip=10 count=$PAYLOAD 2>/dev/null
# 3. zlib stream = 78 9C + deflate + adler
printf '\170\234' > "$T/zlib.bin"
cat "$T/deflate.bin" >> "$T/zlib.bin"
cat "$T/adler.bin" >> "$T/zlib.bin"
ZLEN=$(wc -c < "$T/zlib.bin")
# 4. IHDR data
gawk -v W="$W" -v H="$H" 'BEGIN{printf "%c%c%c%c%c%c%c%c%c%c%c%c%c", and(rshift(W,24),255),and(rshift(W,16),255),and(rshift(W,8),255),and(W,255),and(rshift(H,24),255),and(rshift(H,16),255),and(rshift(H,8),255),and(H,255),8,6,0,0,0}' > "$T/ihdr.bin"
# 5. write PNG
# signature
printf '\211PNG\r\n\032\n' > "$OUT"
# IHDR chunk: len(13) + type + data + crc
printf '\000\000\000\015IHDR' >> "$OUT"
cat "$T/ihdr.bin" >> "$OUT"
(printf 'IHDR'; cat "$T/ihdr.bin") | od -A n -t u1 | gawk -f "$AWKDIR/crc32.awk" >> "$OUT"
# IDAT chunk
gawk -v L="$ZLEN" 'BEGIN{printf "%c%c%c%cIDAT", and(rshift(L,24),255),and(rshift(L,16),255),and(rshift(L,8),255),and(L,255)}' >> "$OUT"
cat "$T/zlib.bin" >> "$OUT"
(printf 'IDAT'; cat "$T/zlib.bin") | od -A n -t u1 | gawk -f "$AWKDIR/crc32.awk" >> "$OUT"
# IEND chunk
printf '\000\000\000\000IEND' >> "$OUT"
printf 'IEND' | od -A n -t u1 | gawk -f "$AWKDIR/crc32.awk" >> "$OUT"
echo "wrote $OUT ($W x $H)"
