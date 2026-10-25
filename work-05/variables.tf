variable "prefix" {
  description = "Префикс имен ресурсов"
  type        = string
  default     = "zarechkin-11"
}

variable "environment" {
  description = "Окружение"
  type        = string
  default     = "test"
}

variable "zone" {
  description = "Зона размещения"
  type        = string
  default     = "ru-central1-d"
}

variable "subnet_cidr" {
  description = "CIDR подсети"
  type        = string
  default     = "10.21.1.0/24"
}

variable "app_port" {
  description = "Порт веб-сервера"
  type        = number
  default     = 8033
}

variable "greeting" {
  description = "Текст веб-страницы"
  type        = string
  default     = "devlab"
}

variable "image_family" {
  description = "Семейство образа ОС"
  type        = string
  default     = "debian-12"
}

variable "web_password" {
  description = "Пароль для доступа к веб-странице"
  type        = string
  sensitive   = true
}

variable "basic_auth_hash" {
  description = "Постоянный bcrypt-хеш пароля"
  type        = string
  sensitive   = true
}

variable "vm_count" {
  description = "Количество виртуальных машин"
  type        = number
  default     = 2

  validation {
    condition     = var.vm_count >= 1 && var.vm_count <= 3 && floor(var.vm_count) == var.vm_count
    error_message = "Количество машин должно быть целым числом от 1 до 3."
  }
}

variable "open_ports" {
  description = "Разрешённые входящие TCP-порты"
  type        = list(number)

  validation {
    condition = (
      length(var.open_ports) > 0 &&
      alltrue([
        for port in var.open_ports :
        port >= 1 && port <= 65535 && floor(port) == port
      ])
    )
    error_message = "Порты должны быть целыми числами от 1 до 65535."
  }
}
