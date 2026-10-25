resource "yandex_vpc_security_group" "web" {
  name       = "${var.prefix}-tf-sg"
  network_id = yandex_vpc_network.net.id

  labels = local.common_labels

  dynamic "ingress" {
    for_each = var.open_ports

    content {
      protocol       = "TCP"
      port           = ingress.value
      v4_cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}
