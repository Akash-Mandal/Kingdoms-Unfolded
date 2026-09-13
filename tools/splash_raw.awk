#!/data/data/com.termux/files/usr/bin/gawk -f
# splash_raw.awk - 1280x720 dark splash with centered gold shield
# usage: gawk -f splash_raw.awk -v W=1280 -v H=720 > raw.bin
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
  S = (H < W ? H : W) * 0.55   # shield pixel size
  ox = (W - S)/2; oy = (H - S)/2 - H*0.06
  for (y = 0; y < H; y++) {
    printf "%c", 0
    for (x = 0; x < W; x++) {
      # dark backdrop #1A1208 with subtle vertical gradient
      g = y/H
      R = int(26 + 8*g); G = int(18 + 6*g); B = int(8 + 3*g)
      # gold underline bar below shield
      if (y >= oy+S+20 && y <= oy+S+26 && x >= W*0.3 && x <= W*0.7) {
        printf "%c%c%c%c", 184, 134, 11, 255; continue
      }
      lx = (x - ox); ly = (y - oy)
      if (lx < 0 || ly < 0 || lx >= S || ly >= S) { printf "%c%c%c%c", R, G, B, 255; continue }
      u = (lx+0.5)/S*128; v = (ly+0.5)/S*128
      if (!shield_outer(u, v)) { printf "%c%c%c%c", R, G, B, 255; continue }
      du = u-64; dv = v-58
      if (du*du+dv*dv <= 64) { printf "%c%c%c%c", 246, 211, 101, 255; continue }
      if (shield_inner(u, v)) { printf "%c%c%c%c", 122, 78, 15, 255; continue }
      if (!shield_outer_eroded(u, v, 3.5)) { printf "%c%c%c%c", 122, 78, 15, 255; continue }
      s = ((u-12)+(v-4))/226
      if (s<0) s=0; if (s>1) s=1
      RR = int(246 + (184-246)*s); GG = int(211 + (134-211)*s); BB = int(101 + (11-101)*s)
      printf "%c%c%c%c", RR, GG, BB, 255
    }
  }
}
