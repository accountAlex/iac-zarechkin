prefix       = "zarechkin-11"
environment  = "test"
zone         = "ru-central1-d"
subnet_cidr  = "10.21.1.0/24"
app_port     = 8033
greeting     = "devlab"
image_family = "debian-12"

open_ports = [22, 8033]
