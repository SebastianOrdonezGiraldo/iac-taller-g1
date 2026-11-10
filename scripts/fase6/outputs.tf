output "urls" {
  value = [
    module.tienda.url,
    module.blog.url,
    module.docs.url,
  ]
}

output "red_driver" {
  value = data.docker_network.bridge.driver
}
