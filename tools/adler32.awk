# adler32.awk - Adler-32 over decimal bytes on stdin, prints 4 raw bytes BE
BEGIN { a = 1; b = 0 }
{ for (i = 1; i <= NF; i++) { a = (a + $i) % 65521; b = (b + a) % 65521 } }
END { s = b*65536 + a; printf "%c%c%c%c", and(rshift(s,24),255), and(rshift(s,16),255), and(rshift(s,8),255), and(s,255) }
