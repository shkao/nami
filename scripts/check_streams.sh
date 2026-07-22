#!/usr/bin/env bash
#
# check_streams.sh — verify every Nami radio stream is reachable.
#
# Community FM streams change hosts, expire, or start enforcing new request
# headers without notice (the smartstream CDN began returning 403 to requests
# without an Origin header in 2026). Run this regularly to catch breakage
# before users do. Exits non-zero if any station fails.
#
# Usage:  scripts/check_streams.sh
#
# The station list mirrors Nami/Models/Station.swift. Keep them in sync: each
# entry is  "Name|streamURL"  and any URL on mtist.as.smartstream.ne.jp gets
# the Origin header that host now requires (see Station.streamHTTPHeaders).

set -u

STATIONS=(
  "FM Blue Shonan|https://mtist.as.smartstream.ne.jp/30019/livestream/playlist.m3u8"
  "Shonan Beach FM|https://shonanbeachfm.out.airtime.pro/shonanbeachfm_c"
  "Kamakura FM|https://mtist.as.smartstream.ne.jp/30037/livestream/playlist.m3u8"
  "Chofu FM|https://mtist.as.smartstream.ne.jp/30039/livestream/playlist.m3u8"
  "FM Salus|https://mtist.as.smartstream.ne.jp/30048/livestream/playlist.m3u8"
)

SMARTSTREAM_ORIGIN="https://listenradio.jp"
UA="AppleCoreMedia/1.0.0 (Macintosh; U; Intel Mac OS X 15_5)"
TIMEOUT=12

failures=0
printf '%-18s %-7s %s\n' "STATION" "STATUS" "DETAIL"
printf '%-18s %-7s %s\n' "-------" "------" "------"

# Probe one URL once. Echoes "OK <detail>" or "FAIL <detail>".
probe_once() {
  local url="$1"
  local origin_args=()
  if [[ "$url" == *"mtist.as.smartstream.ne.jp"* ]]; then
    origin_args=(-H "Origin: ${SMARTSTREAM_ORIGIN}")
  fi

  local body_file code
  body_file="$(mktemp)"

  if [[ "$url" == *.m3u8 ]]; then
    # HLS playlists are small: fetch in full and confirm it parses.
    code="$(curl -s -o "$body_file" -w '%{http_code}' \
      --max-time "$TIMEOUT" -A "$UA" ${origin_args[@]+"${origin_args[@]}"} \
      "$url" 2>/dev/null)"
    if [[ "$code" == "200" ]] && grep -q "#EXTM3U" "$body_file"; then
      echo "OK HTTP $code"
    else
      echo "FAIL HTTP $code"
    fi
  else
    # Icecast is an endless stream: grab a little and just confirm it opens.
    code="$(curl -s -o "$body_file" -w '%{http_code}' \
      --max-time "$TIMEOUT" -A "$UA" ${origin_args[@]+"${origin_args[@]}"} \
      -r 0-2047 "$url" 2>/dev/null)"
    if [[ "$code" == "200" || "$code" == "206" ]]; then
      echo "OK HTTP $code"
    else
      echo "FAIL HTTP $code"
    fi
  fi
  rm -f "$body_file"
}

for entry in "${STATIONS[@]}"; do
  name="${entry%%|*}"
  url="${entry#*|}"

  # One retry absorbs transient CDN blips before declaring a station down.
  result="$(probe_once "$url")"
  if [[ "$result" == FAIL* ]]; then
    sleep 2
    result="$(probe_once "$url")"
  fi

  status="${result%% *}"
  detail="${result#* }"
  printf '%-18s %-7s %s\n' "$name" "$status" "$detail"
  [[ "$status" == "FAIL" ]] && failures=$((failures + 1))
done

echo
if [[ "$failures" -gt 0 ]]; then
  echo "$failures station(s) failed."
  exit 1
fi
echo "All streams healthy."
