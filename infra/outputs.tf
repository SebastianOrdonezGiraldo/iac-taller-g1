output "urls" {
  value = { for k, m in module.sitio : m.nombre => m.url }
}

output "red_driver" {
  value = data.docker_network.bridge.driver
}
