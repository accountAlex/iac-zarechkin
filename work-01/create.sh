#!/usr/bin/env bash
set -euo pipefail

PREFIX="zarechkin-11"
ZONE="ru-central1-b"
CIDR="10.21.1.0/24"
PORT="8033"
DISK_SIZE="20"
IMAGE_FAMILY="debian-12"
WORD="devlab"

NETWORK_NAME="${PREFIX}-net"
SUBNET_NAME="${PREFIX}-subnet"
SSH_KEY="${HOME}/.ssh/id_ed25519.pub"

echo "Создание сети ${NETWORK_NAME}..."
yc vpc network create \
  --name "${NETWORK_NAME}"

echo "Создание подсети ${SUBNET_NAME}..."
yc vpc subnet create \
  --name "${SUBNET_NAME}" \
  --network-name "${NETWORK_NAME}" \
  --zone "${ZONE}" \
  --range "${CIDR}"

echo "Создание ${PREFIX}-app-1..."
yc compute instance create \
  --name "${PREFIX}-app-1" \
  --zone "${ZONE}" \
  --platform standard-v3 \
  --cores=2 \
  --core-fraction=20 \
  --memory=2 \
  --preemptible \
  --create-boot-disk \
    image-folder-id=standard-images,\
image-family="${IMAGE_FAMILY}",\
type=network-hdd,\
size="${DISK_SIZE}" \
  --network-interface \
    subnet-name="${SUBNET_NAME}",\
nat-ip-version=ipv4 \
  --hostname "${PREFIX}-app-1" \
  --ssh-key "${SSH_KEY}" \
  --labels created-by=cli

echo "Создание ${PREFIX}-app-2..."
yc compute instance create \
  --name "${PREFIX}-app-2" \
  --zone "${ZONE}" \
  --platform standard-v3 \
  --cores=2 \
  --core-fraction=20 \
  --memory=2 \
  --preemptible \
  --create-boot-disk \
    image-folder-id=standard-images,\
image-family="${IMAGE_FAMILY}",\
type=network-hdd,\
size="${DISK_SIZE}" \
  --network-interface \
    subnet-name="${SUBNET_NAME}",\
nat-ip-version=ipv4 \
  --hostname "${PREFIX}-app-2" \
  --ssh-key "${SSH_KEY}" \
  --labels created-by=cli

echo
echo "Стенд создан."
echo "Префикс: ${PREFIX}"
echo "Зона: ${ZONE}"
echo "Подсеть: ${CIDR}"
echo "Порт nginx: ${PORT}"
echo "Диск: ${DISK_SIZE} ГБ"
echo "Образ: ${IMAGE_FAMILY}"
echo "Слово: ${WORD}"