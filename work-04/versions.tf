terraform {
  required_version = ">= 1.8"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.220.0"
    }
  }
}

provider "yandex" {
  service_account_key_file = pathexpand("~/.yc-keys/zarechkin-11-key.json")

  cloud_id  = "b1goad0fhmbdurgq34mq"
  folder_id = "b1gh5mrs65v8qh0brtoh"
  zone      = "ru-central1-d"
}
