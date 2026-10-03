#!/usr/bin/env bash
set -euo pipefail

PREFIX=zarechkin-11

echo "==> удаление балансировщика"
if yc load-balancer network-load-balancer get "$PREFIX-lb" >/dev/null 2>&1; then
  yc load-balancer network-load-balancer delete "$PREFIX-lb"
else
  echo "$PREFIX-lb уже отсутствует"
fi

echo "==> удаление целевой группы"
if yc load-balancer target-group get "$PREFIX-tg" >/dev/null 2>&1; then
  yc load-balancer target-group delete "$PREFIX-tg"
else
  echo "$PREFIX-tg уже отсутствует"
fi

echo "==> удаление виртуальных машин"
for VM_NAME in $(yc compute instance list --format json \
  | jq -r --arg prefix "$PREFIX-app-" \
  '.[] | select(.name | startswith($prefix)) | .name'); do

  echo "Удаление $VM_NAME"
  yc compute instance delete "$VM_NAME"
done

echo "==> удаление дополнительного диска"
if yc compute disk get "$PREFIX-data" >/dev/null 2>&1; then
  yc compute disk delete "$PREFIX-data"
else
  echo "$PREFIX-data уже отсутствует"
fi

echo "==> удаление подсетей"

if yc vpc subnet get "$PREFIX-subnet-a" >/dev/null 2>&1; then
  yc vpc subnet delete "$PREFIX-subnet-a"
else
  echo "$PREFIX-subnet-a уже отсутствует"
fi

if yc vpc subnet get "$PREFIX-subnet-b" >/dev/null 2>&1; then
  yc vpc subnet delete "$PREFIX-subnet-b"
else
  echo "$PREFIX-subnet-b уже отсутствует"
fi

echo "==> удаление сети"
if yc vpc network get "$PREFIX-net" >/dev/null 2>&1; then
  yc vpc network delete "$PREFIX-net"
else
  echo "$PREFIX-net уже отсутствует"
fi

echo "==> очистка завершена"