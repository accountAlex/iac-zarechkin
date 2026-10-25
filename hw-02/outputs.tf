# URL балансировщика для проверки HTTP-запросов.
output "lb_url" {
  value = "http://${one(flatten([
    for l in yandex_lb_network_load_balancer.lb.listener : [
      for spec in l.external_address_spec : spec.address
    ]
  ]))}"
}

# Публичные адреса веб-серверов.
output "web_ips" {
  value = yandex_compute_instance.web[*].network_interface[0].nat_ip_address
}
