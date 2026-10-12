#!/usr/bin/env bash
set -euo pipefail

PREFIX="zarechkin-11"
GREETING="devlab"

echo "==> проверка балансировщика"

LB_IP=$(yc load-balancer network-load-balancer get \
  --name "$PREFIX-lb" \
  --format json \
  | jq -r '.listeners[0].address')

if [ -z "$LB_IP" ] || [ "$LB_IP" = "null" ]; then
  echo "Ошибка: публичный IP балансировщика не найден"
  exit 1
fi

echo "LB_IP=$LB_IP"

echo "==> ожидание ответа сервиса"

for _ in $(seq 1 30); do
  if BODY=$(curl -fsS \
    --connect-timeout 3 \
    --max-time 5 \
    "http://$LB_IP/"); then

    echo "Получен ответ: $BODY"

    if printf '%s' "$BODY" | grep -q "$GREETING"; then
      echo "Проверка успешна: найдено слово $GREETING"
      exit 0
    fi
  fi

  sleep 5
done

echo "Ошибка: сервис не прошёл проверку"
exit 1
