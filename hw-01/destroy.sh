#!/usr/bin/env bash

PREFIX="${PREFIX:-zarechkin-11}"

echo "==> удаление стенда $PREFIX"

# --------------------------------------------------
# 1. Балансировщик
# --------------------------------------------------

if yc load-balancer network-load-balancer get \
  --name "$PREFIX-lb" >/dev/null 2>&1; then

  echo "Удаляю балансировщик $PREFIX-lb"
  yc load-balancer network-load-balancer delete \
    --name "$PREFIX-lb"
else
  echo "Балансировщик $PREFIX-lb не найден, пропускаю"
fi

# --------------------------------------------------
# 2. Целевая группа
# --------------------------------------------------

if yc load-balancer target-group get \
  --name "$PREFIX-tg" >/dev/null 2>&1; then

  echo "Удаляю целевую группу $PREFIX-tg"
  yc load-balancer target-group delete \
    --name "$PREFIX-tg"
else
  echo "Целевая группа $PREFIX-tg не найдена, пропускаю"
fi

# --------------------------------------------------
# 3. Виртуальные машины по префиксу
# --------------------------------------------------

VM_NAMES=$(yc compute instance list \
  --format json \
  | jq -r --arg prefix "$PREFIX-" \
    '.[] | select(.name | startswith($prefix)) | .name')

if [ -n "$VM_NAMES" ]; then
  echo "$VM_NAMES" | while IFS= read -r VM_NAME; do
    [ -z "$VM_NAME" ] && continue

    echo "Удаляю ВМ $VM_NAME"
    yc compute instance delete "$VM_NAME"
  done
else
  echo "Виртуальные машины с префиксом $PREFIX не найдены"
fi

# --------------------------------------------------
# 4. Отключение таблицы маршрутизации от подсети A
# --------------------------------------------------

if yc vpc subnet get \
  --name "$PREFIX-subnet-a" >/dev/null 2>&1; then

  ROUTE_TABLE_ID=$(yc vpc subnet get \
    --name "$PREFIX-subnet-a" \
    --format json \
    | jq -r '.route_table_id // ""')

  if [ -n "$ROUTE_TABLE_ID" ]; then
    echo "Отключаю таблицу маршрутизации от $PREFIX-subnet-a"

    yc vpc subnet update \
      --name "$PREFIX-subnet-a" \
      --disassociate-route-table
  else
    echo "Таблица маршрутизации уже отключена от $PREFIX-subnet-a"
  fi
fi

# --------------------------------------------------
# 5. Таблица маршрутизации
# --------------------------------------------------

if yc vpc route-table get \
  --name "$PREFIX-rt" >/dev/null 2>&1; then

  echo "Удаляю таблицу маршрутизации $PREFIX-rt"
  yc vpc route-table delete \
    --name "$PREFIX-rt"
else
  echo "Таблица маршрутизации $PREFIX-rt не найдена, пропускаю"
fi

# --------------------------------------------------
# 6. NAT-шлюз
# --------------------------------------------------

if yc vpc gateway get \
  --name "$PREFIX-nat" >/dev/null 2>&1; then

  echo "Удаляю NAT-шлюз $PREFIX-nat"
  yc vpc gateway delete \
    --name "$PREFIX-nat"
else
  echo "NAT-шлюз $PREFIX-nat не найден, пропускаю"
fi

# --------------------------------------------------
# 7. Подсети
# --------------------------------------------------

for SUBNET in "$PREFIX-subnet-a" "$PREFIX-subnet-b"; do
  if yc vpc subnet get "$SUBNET" >/dev/null 2>&1; then
    echo "Удаляю подсеть $SUBNET"
    yc vpc subnet delete "$SUBNET"
  else
    echo "Подсеть $SUBNET не найдена, пропускаю"
  fi
done

# --------------------------------------------------
# 8. Сеть
# --------------------------------------------------

if yc vpc network get "$PREFIX-net" >/dev/null 2>&1; then
  echo "Удаляю сеть $PREFIX-net"
  yc vpc network delete "$PREFIX-net"
else
  echo "Сеть $PREFIX-net не найдена, пропускаю"
fi

echo "==> стенд удалён"
