terraform {
  required_version = ">= 1.8"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.220.0"
    }
  }
}

# Доступ к облаку передаётся через переменные окружения YC_*.
# Это позволяет проверять манифест в GitLab CI без локального файла ключа.
provider "yandex" {}
