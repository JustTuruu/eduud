#!/usr/bin/env bash
# Flutter аппыг backend-тэй холбож ажиллуулна.
# Хэрэглээ: ./tool/run.sh -d <төхөөрөмж>   (жиш. -d chrome, -d <iPhone id>)
# Backend (API :3000, Socket.IO :3001) заавал ажиллаж байх ёстой.
# Бодит утас компьютертэйгээ нэг Wi-Fi дээр байх ёстой.
set -euo pipefail
cd "$(dirname "$0")/.."

# -d chrome / -d web-server үед localhost, бусад үед компьютерийн LAN IP.
HOST=""
args=("$@")
for ((i = 0; i < ${#args[@]}; i++)); do
  case "${args[$i]}" in
    -d|--device-id)
      [[ "${args[$((i + 1))]:-}" == chrome || "${args[$((i + 1))]:-}" == web-server ]] && HOST=localhost ;;
    -dchrome|--device-id=chrome) HOST=localhost ;;
  esac
done

if [[ -z "$HOST" ]]; then
  HOST="$(ipconfig getifaddr en0 2>/dev/null || true)"
  [[ -z "$HOST" ]] && HOST="$(ipconfig getifaddr en1 2>/dev/null || true)"
  if [[ -z "$HOST" ]]; then
    echo "LAN IP олдсонгүй. Wi-Fi-д холбогдсон эсэхээ шалгана уу." >&2
    exit 1
  fi
fi

echo "API: http://$HOST:3000  Socket: http://$HOST:3001"
exec flutter run \
  --dart-define=API_URL="http://$HOST:3000" \
  --dart-define=SOCKET_URL="http://$HOST:3001" \
  "$@"
