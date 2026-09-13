# crc32.awk - IEEE CRC32 over decimal bytes on stdin (od -A n -t u1 output)
# prints 4 raw bytes BE to stdout
BEGIN {
  for (i = 0; i < 256; i++) {
    c = i
    for (k = 0; k < 8; k++) c = (and(c, 1) ? xor(rshift(c, 1), 0xEDB88320) : rshift(c, 1))
    tbl[i] = c
  }
  crc = 0xFFFFFFFF
}
{ for (i = 1; i <= NF; i++) { b = $i + 0; crc = xor(tbl[xor(and(crc, 255), b)], rshift(crc, 8)) } }
END {
  crc = xor(crc, 0xFFFFFFFF)
  printf "%c%c%c%c", and(rshift(crc,24),255), and(rshift(crc,16),255), and(rshift(crc,8),255), and(crc,255)
}
