
# Сеть
resource "yandex_vpc_network" "net" {
  name = local.network_name
}

# Подсеть
resource "yandex_vpc_subnet" "subnet" {
  name           = local.subnet_name
  zone           = var.zone
  network_id     = yandex_vpc_network.net.id
  v4_cidr_blocks = [var.subnet_cidr]
}

# Образ Debian 12
data "yandex_compute_image" "base" {
  family = var.image_family
}

# Виртуальная машина
resource "yandex_compute_instance" "app" {
  for_each = toset([
    for i in range(var.vm_count) : tostring(i + 1)
  ])
  name                      = (each.key == "1" ? local.app_name : "${local.app_name}-${each.key}")
  hostname                  = (each.key == "1" ? local.app_name : "${local.app_name}-${each.key}")
  zone                      = var.zone
  platform_id               = "standard-v3"
  allow_stopping_for_update = true

  dynamic "secondary_disk" {
    for_each = each.key == "1" ? [1] : []
    content {
      disk_id = yandex_compute_disk.extra.id
    }
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
    subnet_id          = yandex_vpc_subnet.subnet.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.web.id]
  }

  metadata = {
    serial-port-enable = "1"
    user-data = templatefile("${path.module}/cloud-init.tpl.yaml", {
      ssh_key         = trimspace(file(pathexpand("~/.ssh/id_ed25519.pub")))
      app_port        = var.app_port
      greeting        = var.greeting
      basic_auth_user = local.basic_auth_user
      basic_auth_hash = local.basic_auth_hash
    })
  }

  labels = {
    env   = var.environment
    owner = var.prefix
  }
}

# Публичный IP-адрес виртуальной машины


resource "yandex_compute_disk" "extra" {
  name = local.disk_name
  zone = var.zone
  size = 10
  type = "network-ssd"
}

# Сохранение существующей виртуальной машины
# при переходе на for_each
moved {
  from = yandex_compute_instance.app
  to   = yandex_compute_instance.app["1"]
}
