#!/usr/bin/env bash

PREFIX="${PREFIX:-zarechkin-11}"
APP_PORT="${APP_PORT:-8033}"

RESULT=0

echo "==> проверка стенда"

# --------------------------------------------------
# 1. Проверка наличия балансировщика
# --------------------------------------------------

if ! yc load-balancer network-load-balancer get \
  --name "$PREFIX-lb" >/dev/null 2>&1; then

  echo "✗ балансировщик $PREFIX-lb не найден"
  exit 1
fi

LB_IP=$(yc load-balancer network-load-balancer get \
  --name "$PREFIX-lb" \
  --format json \
  | jq -r '.listeners[0].address')

# --------------------------------------------------
# 2. Балансировщик должен отвечать HTTP 200
# --------------------------------------------------

HTTP_CODE="000"

for i in 1 2 3 4 5; do
  CODE=$(curl -s \
    --connect-timeout 5 \
    --max-time 10 \
    -o /dev/null \
    -w '%{http_code}' \
    "http://$LB_IP/")

  if [ "$CODE" = "200" ]; then
    HTTP_CODE="$CODE"
    break
  fi

  HTTP_CODE="$CODE"
  sleep 1
done

if [ "$HTTP_CODE" = "200" ]; then
  echo "✓ балансировщик отвечает: HTTP 200"
else
  echo "✗ балансировщик не отвечает корректно: HTTP $HTTP_CODE"
  RESULT=1
fi

# --------------------------------------------------
# 3. Проверка ответов нескольких web-серверов
# --------------------------------------------------

TMP_FILE=$(mktemp)

for i in $(seq 1 20); do
  BODY=$(curl -s \
    --connect-timeout 3 \
    --max-time 5 \
    "http://$LB_IP/")

  if [ -n "$BODY" ]; then
    echo "$BODY" \
      | grep -o "$PREFIX-web-[0-9]*" \
      >> "$TMP_FILE"
  fi
done

WEB_NAMES=$(sort -u "$TMP_FILE" | tr '\n' ' ')
WEB_COUNT=$(sort -u "$TMP_FILE" | awk 'NF {count++} END {print count+0}')

rm -f "$TMP_FILE"

if [ "$WEB_COUNT" -gt 1 ]; then
  echo "✓ ответили машины: $WEB_NAMES"
else
  echo "✗ отвечает меньше двух web-серверов: ${WEB_NAMES:-нет ответов}"
  RESULT=1
fi

# --------------------------------------------------
# 4. Проверка app-сервера из web-1
# --------------------------------------------------

WEB1_PUBLIC_IP=$(yc compute instance get "$PREFIX-web-1" \
  --format json \
  | jq -r '.network_interfaces[0].primary_v4_address.one_to_one_nat.address')

APP_INTERNAL_IP=$(yc compute instance get "$PREFIX-app" \
  --format json \
  | jq -r '.network_interfaces[0].primary_v4_address.address')

APP_RESPONSE=$(ssh \
  -o ConnectTimeout=10 \
  -o StrictHostKeyChecking=accept-new \
  "student@$WEB1_PUBLIC_IP" \
  "curl -s --connect-timeout 5 --max-time 10 http://$APP_INTERNAL_IP:$APP_PORT/" \
  2>/dev/null || true)

if echo "$APP_RESPONSE" | grep -q "$PREFIX-app"; then
  echo "✓ сервер приложения доступен с web-1: $APP_INTERNAL_IP:$APP_PORT"
else
  echo "✗ сервер приложения недоступен с web-1"
  RESULT=1
fi

# --------------------------------------------------
# Итог
# --------------------------------------------------

if [ "$RESULT" -eq 0 ]; then
  echo "✓ стенд исправен"
else
  echo "✗ стенд не в норме"
fi

exit "$RESULT"
