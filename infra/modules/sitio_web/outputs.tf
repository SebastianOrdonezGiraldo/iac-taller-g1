output "url" {
  value = "http://localhost:${var.puerto}"
}

output "nombre" {
  value = docker_container.this.name
}
