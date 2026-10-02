export PREFIX=zarechkin-11
export ZONE=ru-central1-b
export CIDR=10.21.1.0/24
export DISK_SIZE=20
export IMAGE_FAMILY=debian-12

yc vpc network create --name "$PREFIX-net"

yc vpc subnet create \
  --name "$PREFIX-subnet" \
  --network-name "$PREFIX-net" \
  --zone "$ZONE" \
  --range "$CIDR"

yc compute instance create \
  --name "$PREFIX-app-1" \
  --zone "$ZONE" \
  --platform standard-v3 \
  --cores=2 \
  --core-fraction=20 \
  --memory=2 \
  --preemptible \
  --create-boot-disk \
    image-folder-id=standard-images,\
image-family="$IMAGE_FAMILY",\
type=network-hdd,\
size="$DISK_SIZE" \
  --network-interface \
    subnet-name="$PREFIX-subnet",\
nat-ip-version=ipv4 \
  --hostname "$PREFIX-app-1" \
  --ssh-key "$HOME/.ssh/id_ed25519.pub" \
  --labels created-by=cli

yc compute instance create \
  --name "$PREFIX-app-2" \
  --zone "$ZONE" \
  --platform standard-v3 \
  --cores=2 \
  --core-fraction=20 \
  --memory=2 \
  --preemptible \
  --create-boot-disk \
    image-folder-id=standard-images,\
image-family="$IMAGE_FAMILY",\
type=network-hdd,\
size="$DISK_SIZE" \
  --network-interface \
    subnet-name="$PREFIX-subnet",\
nat-ip-version=ipv4 \
  --hostname "$PREFIX-app-2" \
  --ssh-key "$HOME/.ssh/id_ed25519.pub" \
  --labels created-by=cli

yc compute instance delete --name "$PREFIX-app-1"

yc compute instance delete --name "$PREFIX-app-2"

yc vpc subnet delete --name "$PREFIX-subnet"

yc vpc network delete --name "$PREFIX-net"