
# Сеть
resource "yandex_vpc_network" "net" {
  name = "zarechkin-11-tf-net"
}

# Подсеть
resource "yandex_vpc_subnet" "subnet" {
  name           = "zarechkin-11-tf-subnet"
  zone           = "ru-central1-d"
  network_id     = yandex_vpc_network.net.id
  v4_cidr_blocks = ["10.21.1.0/24"]
}

# Образ Debian 12
data "yandex_compute_image" "base" {
  family = "debian-12"
}

# Виртуальная машина
resource "yandex_compute_instance" "app" {
  name                      = "zarechkin-11-tf-app"
  hostname                  = "zarechkin-11-tf-app"
  zone                      = "ru-central1-d"
  platform_id               = "standard-v3"
  allow_stopping_for_update = true

  secondary_disk {
    disk_id = yandex_compute_disk.extra.id
  }

  resources {
    cores         = 2
    core_fraction = 20
    memory        = 4
  }

  scheduling_policy {
    preemptible = true
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.base.id
      size     = 20
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet.id
    nat       = true
  }

  metadata = {
    user-data = templatefile("${path.module}/cloud-init.tpl.yaml", {
      ssh_key = trimspace(file(pathexpand("~/.ssh/id_ed25519.pub")))
    })
  }

  labels = {
    env   = "test"
    owner = "zarechkin-11"
  }
}

# Публичный IP-адрес виртуальной машины
output "app_ip" {
  description = "Публичный адрес машины"
  value       = yandex_compute_instance.app.network_interface.0.nat_ip_address
}

resource "yandex_compute_disk" "extra" {
  name = "zarechkin-11-tf-extra"
  zone = "ru-central1-d"
  size = 10
  type = "network-ssd"
}
