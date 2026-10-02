#!/usr/bin/env bash
set -euo pipefail

PREFIX="zarechkin-11"

NETWORK_NAME="${PREFIX}-net"
SUBNET_NAME="${PREFIX}-subnet"

echo "Удаление ${PREFIX}-app-1..."
yc compute instance delete \
  --name "${PREFIX}-app-1"

echo "Удаление ${PREFIX}-app-2..."
yc compute instance delete \
  --name "${PREFIX}-app-2"

echo "Удаление подсети ${SUBNET_NAME}..."
yc vpc subnet delete \
  --name "${SUBNET_NAME}"

echo "Удаление сети ${NETWORK_NAME}..."
yc vpc network delete \
  --name "${NETWORK_NAME}"

echo
echo "Стенд ${PREFIX} полностью удалён."