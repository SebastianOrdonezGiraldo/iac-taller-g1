output "url" {
  value = "http://localhost:${var.puerto}"
}

output "contenedor" {
  value = docker_container.web.name
}

output "red_driver" {
  value = data.docker_network.bridge.driver
}
