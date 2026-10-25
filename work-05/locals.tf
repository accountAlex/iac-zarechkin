locals {
  basic_auth_user = "student"
  basic_auth_hash = var.basic_auth_hash
  network_name    = "${var.prefix}-tf-net"
  subnet_name     = "${var.prefix}-tf-subnet"
  app_name        = "${var.prefix}-tf-app"
  disk_name       = "${var.prefix}-tf-extra"

  common_labels = {
    env   = var.environment
    owner = var.prefix
  }
}
