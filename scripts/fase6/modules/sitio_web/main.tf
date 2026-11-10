locals {
  html = <<-EOT
    <h1>${var.mensaje}</h1>
    <p>Sitio ${var.nombre}, desplegado con Terraform</p>
  EOT
}

resource "docker_image" "this" {
  name         = var.imagen
  keep_locally = true
}

resource "docker_container" "this" {
  name  = var.nombre
  image = docker_image.this.image_id

  ports {
    internal = 80
    external = var.puerto
  }

  upload {
    content = local.html
    file    = "/usr/share/nginx/html/index.html"
  }
}
