#!/data/data/com.termux/files/usr/bin/gawk -f
# shield_raw.awk - writes raw PNG scanlines (filter 0 + RGBA) to stdout (binary)
# usage: gawk -f shield_raw.awk -v SIZE=512 -v MODE=shield > raw.bin
# MODE: shield (transparent bg), background (solid brown gradient), splash handled separately
function shield_outer(u, v,   t, l, r, k) {
  if (v < 4 || v > 126 || u < 12 || u > 116) return 0
  if (u <= 64) t = 4 + 18*(64-u)/52
  else t = 4 + 18*(u-64)/52
  if (v < t) return 0
  if (v <= 62) { l = 12; r = 116 }
  else { k = (v-62)/64; k = k^1.3; l = 12 + 52*k; r = 116 - 52*k }
  return (u >= l && u <= r)
}
function shield_outer_eroded(u, v, e,   t, l, r, k) {
  if (v < 4+e || v > 126-e || u < 12+e || u > 116-e) return 0
  if (u <= 64) t = 4 + 18*(64-u)/52
  else t = 4 + 18*(u-64)/52
  if (v < t+e) return 0
  if (v <= 62) { l = 12+e; r = 116-e }
  else { k = (v-62)/64; if (k<0) k=0; k = k^1.3; l = 12 + 52*k + e; r = 116 - 52*k - e; if (l>r) return 0 }
  return (u >= l && u <= r)
}
function shield_inner(u, v,   t, l, r, k) {
  if (v < 26 || v > 102 || u < 44 || u > 84) return 0
  if (u <= 64) t = 26 + 10*(64-u)/20
  else t = 26 + 10*(u-64)/20
  if (v < t) return 0
  if (v <= 58) { l = 44; r = 84 }
  else { k = (v-58)/44; k = k^1.2; l = 44 + 20*k; r = 84 - 20*k; if (l>r) return 0 }
  return (u >= l && u <= r)
}
BEGIN {
  N = SIZE+0
  for (y = 0; y < N; y++) {
    printf "%c", 0  # filter byte None
    for (x = 0; x < N; x++) {
      u = (x+0.5)/N*128; v = (y+0.5)/N*128
      if (MODE == "background") {
        s = (x+y)/(2*N)  # 0..1 diagonal
        R = int(122 + (70-122)*s); G = int(78 + (45-78)*s); B = int(15 + (8-15)*s)
        printf "%c%c%c%c", R, G, B, 255
        continue
      }
      # shield mode: transparent outside
      if (!shield_outer(u, v)) { printf "%c%c%c%c", 0, 0, 0, 0; continue }
      # circle jewel on top
      du = u-64; dv = v-58
      if (du*du+dv*dv <= 64) { printf "%c%c%c%c", 246, 211, 101, 255; continue }
      if (shield_inner(u, v)) { printf "%c%c%c%c", 122, 78, 15, 255; continue }
      if (!shield_outer_eroded(u, v, 3.5)) { printf "%c%c%c%c", 122, 78, 15, 255; continue }
      s = ((u-12)+(v-4))/226  # 0..1 gradient
      if (s<0) s=0; if (s>1) s=1
      R = int(246 + (184-246)*s); G = int(211 + (134-211)*s); B = int(101 + (11-101)*s)
      printf "%c%c%c%c", R, G, B, 255
    }
  }
}
