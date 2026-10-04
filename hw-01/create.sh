#!/usr/bin/env bash
set -euo pipefail

# Значения варианта
PREFIX_DEFAULT="zarechkin-11"
ZONE_A_DEFAULT="ru-central1-b"
ZONE_B_DEFAULT="ru-central1-d"
CIDR_A_DEFAULT="10.21.1.0/24"
CIDR_B_DEFAULT="10.21.2.0/24"
APP_PORT_DEFAULT="8033"
GREETING_DEFAULT="devlab"
WEB_COUNT_DEFAULT="2"
ENV_NAME_DEFAULT="test"

# Переменная окружения имеет приоритет над значением варианта
PREFIX="${PREFIX:-$PREFIX_DEFAULT}"
ZONE_A="${ZONE_A:-$ZONE_A_DEFAULT}"
ZONE_B="${ZONE_B:-$ZONE_B_DEFAULT}"
CIDR_A="${CIDR_A:-$CIDR_A_DEFAULT}"
CIDR_B="${CIDR_B:-$CIDR_B_DEFAULT}"
APP_PORT="${APP_PORT:-$APP_PORT_DEFAULT}"
GREETING="${GREETING:-$GREETING_DEFAULT}"
WEB_COUNT="${WEB_COUNT:-$WEB_COUNT_DEFAULT}"
ENV_NAME="${ENV_NAME:-$ENV_NAME_DEFAULT}"

# Аргументы командной строки имеют максимальный приоритет
while [ "$#" -gt 0 ]; do
  case "$1" in
    --prefix)
      PREFIX="$2"
      shift 2
      ;;
    --web-count)
      WEB_COUNT="$2"
      shift 2
      ;;
    --app-port)
      APP_PORT="$2"
      shift 2
      ;;
    --greeting)
      GREETING="$2"
      shift 2
      ;;
    --env)
      ENV_NAME="$2"
      shift 2
      ;;
    *)
      echo "Неизвестный аргумент: $1"
      exit 1
      ;;
  esac
done

echo "PREFIX=$PREFIX"
echo "ZONE_A=$ZONE_A"
echo "ZONE_B=$ZONE_B"
echo "CIDR_A=$CIDR_A"
echo "CIDR_B=$CIDR_B"
echo "APP_PORT=$APP_PORT"
echo "GREETING=$GREETING"
echo "WEB_COUNT=$WEB_COUNT"
echo "ENV_NAME=$ENV_NAME"

echo "==> сеть"

if yc vpc network get "$PREFIX-net" >/dev/null 2>&1; then
  echo "Сеть $PREFIX-net уже существует, пропускаю"
else
  yc vpc network create \
    --name "$PREFIX-net"
fi

echo "==> подсеть A"

if yc vpc subnet get "$PREFIX-subnet-a" >/dev/null 2>&1; then
  echo "Подсеть $PREFIX-subnet-a уже существует, пропускаю"
else
  yc vpc subnet create \
    --name "$PREFIX-subnet-a" \
    --network-name "$PREFIX-net" \
    --zone "$ZONE_A" \
    --range "$CIDR_A"
fi

echo "==> подсеть B"

if yc vpc subnet get "$PREFIX-subnet-b" >/dev/null 2>&1; then
  echo "Подсеть $PREFIX-subnet-b уже существует, пропускаю"
else
  yc vpc subnet create \
    --name "$PREFIX-subnet-b" \
    --network-name "$PREFIX-net" \
    --zone "$ZONE_B" \
    --range "$CIDR_B"
fi

echo "==> NAT-шлюз"

if yc vpc gateway get --name "$PREFIX-nat" >/dev/null 2>&1; then
  echo "NAT-шлюз $PREFIX-nat уже существует, пропускаю"
else
  yc vpc gateway create \
    --name "$PREFIX-nat"
fi

GW_ID=$(yc vpc gateway get \
  --name "$PREFIX-nat" \
  --format json | jq -r '.id')

echo "==> таблица маршрутизации"

if yc vpc route-table get --name "$PREFIX-rt" >/dev/null 2>&1; then
  echo "Таблица маршрутизации $PREFIX-rt уже существует, пропускаю"
else
  yc vpc route-table create \
    --name "$PREFIX-rt" \
    --network-name "$PREFIX-net" \
    --route "destination=0.0.0.0/0,gateway-id=$GW_ID"
fi

RT_ID=$(yc vpc route-table get \
  --name "$PREFIX-rt" \
  --format json | jq -r '.id')

echo "==> подключение таблицы маршрутизации к подсети A"

CURRENT_RT_ID=$(yc vpc subnet get "$PREFIX-subnet-a" \
  --format json | jq -r '.route_table_id // ""')

if [ "$CURRENT_RT_ID" = "$RT_ID" ]; then
  echo "Таблица $PREFIX-rt уже назначена подсети $PREFIX-subnet-a"
else
  yc vpc subnet update \
    --name "$PREFIX-subnet-a" \
    --route-table-name "$PREFIX-rt"
fi

echo "==> генерация cloud-init"

SSH_KEY=$(cat ~/.ssh/id_ed25519.pub)

export APP_PORT
export GREETING
export SSH_KEY

envsubst '${APP_PORT} ${GREETING} ${SSH_KEY}' \
  < hw-01/cloud-init.tpl.yaml \
  > hw-01/cloud-init.yaml

ZONES=("$ZONE_A" "$ZONE_B")
SUBNETS=("$PREFIX-subnet-a" "$PREFIX-subnet-b")

echo "==> веб-серверы"

for i in $(seq 1 "$WEB_COUNT"); do
  idx=$(( (i - 1) % 2 ))
  VM_NAME="$PREFIX-web-$i"

  if yc compute instance get "$VM_NAME" >/dev/null 2>&1; then
    echo "ВМ $VM_NAME уже существует, пропускаю"
  else
    yc compute instance create \
      --name "$VM_NAME" \
      --zone "${ZONES[$idx]}" \
      --platform standard-v3 \
      --cores=2 \
      --core-fraction=20 \
      --memory=2 \
      --preemptible \
      --create-boot-disk image-folder-id=standard-images,image-family=ubuntu-2404-lts,type=network-hdd,size=20 \
      --network-interface subnet-name="${SUBNETS[$idx]}",nat-ip-version=ipv4 \
      --hostname "$VM_NAME" \
      --metadata-from-file user-data=hw-01/cloud-init.yaml
  fi
done

echo "==> сервер приложения"

if yc compute instance get "$PREFIX-app" >/dev/null 2>&1; then
  echo "ВМ $PREFIX-app уже существует, пропускаю"
else
  yc compute instance create \
    --name "$PREFIX-app" \
    --zone "$ZONE_A" \
    --platform standard-v3 \
    --cores=2 \
    --core-fraction=20 \
    --memory=2 \
    --preemptible \
    --create-boot-disk image-folder-id=standard-images,image-family=ubuntu-2404-lts,type=network-hdd,size=20 \
    --network-interface subnet-name="$PREFIX-subnet-a" \
    --hostname "$PREFIX-app" \
    --metadata-from-file user-data=hw-01/cloud-init.yaml
fi

echo "==> целевая группа"

if yc load-balancer target-group get \
  --name "$PREFIX-tg" >/dev/null 2>&1; then

  echo "Целевая группа $PREFIX-tg уже существует, пропускаю"
else
  TARGETS=""

  for i in $(seq 1 "$WEB_COUNT"); do
    idx=$(( (i - 1) % 2 ))
    VM_NAME="$PREFIX-web-$i"

    INTERNAL_IP=$(yc compute instance get "$VM_NAME" \
      --format json \
      | jq -r '.network_interfaces[0].primary_v4_address.address')

    TARGETS="$TARGETS --target subnet-name=${SUBNETS[$idx]},address=$INTERNAL_IP"
  done

  yc load-balancer target-group create \
    --name "$PREFIX-tg" \
    $TARGETS
fi

echo "==> балансировщик"

TG_ID=$(yc load-balancer target-group get \
  --name "$PREFIX-tg" \
  --format json \
  | jq -r '.id')

if yc load-balancer network-load-balancer get \
  --name "$PREFIX-lb" >/dev/null 2>&1; then

  echo "Балансировщик $PREFIX-lb уже существует, пропускаю"
else
  yc load-balancer network-load-balancer create \
    --name "$PREFIX-lb" \
    --region-id ru-central1 \
    --listener name=http,port=80,target-port="$APP_PORT",external-ip-version=ipv4 \
    --target-group target-group-id="$TG_ID",healthcheck-name=http,healthcheck-interval=2s,healthcheck-timeout=1s,healthcheck-unhealthythreshold=2,healthcheck-healthythreshold=2,healthcheck-http-port="$APP_PORT",healthcheck-http-path=/
fi

echo "==> ожидание готовности веб-серверов"

MAX_ATTEMPTS=60
ATTEMPT=1

while [ "$ATTEMPT" -le "$MAX_ATTEMPTS" ]; do
  HEALTHY_COUNT=$(yc load-balancer network-load-balancer target-states \
    --name "$PREFIX-lb" \
    --target-group-id "$TG_ID" \
    --format json \
    | jq '[.[] | select(.status == "HEALTHY")] | length')

  echo "Попытка $ATTEMPT: HEALTHY $HEALTHY_COUNT/$WEB_COUNT"

  if [ "$HEALTHY_COUNT" -eq "$WEB_COUNT" ]; then
    echo "Все веб-серверы готовы"
    break
  fi

  if [ "$ATTEMPT" -eq "$MAX_ATTEMPTS" ]; then
    echo "Ошибка: веб-серверы не стали HEALTHY за отведённое время"
    exit 1
  fi

  ATTEMPT=$((ATTEMPT + 1))
  sleep 5
done

LB_IP=$(yc load-balancer network-load-balancer get \
  --name "$PREFIX-lb" \
  --format json \
  | jq -r '.listeners[0].address')

echo "==> стенд готов"
echo "LB_IP=$LB_IP"