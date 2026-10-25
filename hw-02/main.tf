# Сеть стенда
resource "yandex_vpc_network" "net" {
  name = "zarechkin-11-hw2-net"
}

# Подсеть A
resource "yandex_vpc_subnet" "a" {
  name           = "zarechkin-11-hw2-subnet-a"
  zone           = "ru-central1-e"
  network_id     = yandex_vpc_network.net.id
  v4_cidr_blocks = ["10.21.1.0/24"]
}

# Подсеть B
resource "yandex_vpc_subnet" "b" {
  name           = "zarechkin-11-hw2-subnet-b"
  zone           = "ru-central1-d"
  network_id     = yandex_vpc_network.net.id
  v4_cidr_blocks = ["10.21.2.0/24"]
}

# Образ Debian 12
data "yandex_compute_image" "os" {
  family = "debian-12"
}

# Один блок создаёт две одинаковые ВМ.
# count позволяет впоследствии увеличить стенд изменением одного числа.
resource "yandex_compute_instance" "web" {
  count = 3

  name     = "zarechkin-11-hw2-web-${count.index + 1}"
  hostname = "zarechkin-11-hw2-web-${count.index + 1}"

  # Распределяем машины по двум зонам.
  zone = count.index == 0 ? "ru-central1-e" : "ru-central1-d"

  platform_id = "standard-v3"

  resources {
    cores         = 2
    core_fraction = 20
    memory        = 2
  }

  scheduling_policy {
    preemptible = true
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.os.id
      size     = 20
      type     = count.index == 2 ? "network-ssd" : "network-hdd"
    }
  }

  network_interface {
    # Каждая машина подключается к подсети своей зоны.
    subnet_id = count.index == 0 ? yandex_vpc_subnet.a.id : yandex_vpc_subnet.b.id
    nat       = true
  }

  metadata = {
    user-data = templatefile("${path.module}/cloud-init.tpl.yaml", {
      SSH_KEY  = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILTS5xcYG8NXF/LasM64cTzdOyOhztGY4lXbWlYXpXcp alexander.zarechkin@yandex.ru"
      APP_PORT = 8033
      GREETING = "devlab"
    })
  }

  labels = {
    env   = "test"
    owner = "zarechkin-11"
  }
}

# Целевая группа автоматически включает все веб-серверы.
resource "yandex_lb_target_group" "web" {
  name = "zarechkin-11-hw2-tg"

  dynamic "target" {
    for_each = yandex_compute_instance.web

    content {
      subnet_id = target.value.network_interface.0.subnet_id

      # Балансировщик обращается к внутренним IP машин.
      address = target.value.network_interface.0.ip_address
    }
  }
}

# Сетевой балансировщик распределяет запросы между веб-серверами.
resource "yandex_lb_network_load_balancer" "lb" {
  name = "zarechkin-11-hw2-lb"

  listener {
    name        = "http"
    port        = 80
    target_port = 8033

    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.web.id

    healthcheck {
      name = "http-check"

      http_options {
        port = 8033
        path = "/"
      }
    }
  }
}
