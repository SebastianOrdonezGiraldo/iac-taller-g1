terraform {
  required_version = ">= 1.6"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 4.6"
    }
  }
}

provider "docker" {
  host = "npipe:////.//pipe//docker_engine"
}

resource "docker_image" "nginx" {
  name         = var.imagen
  keep_locally = true
}

resource "docker_container" "web" {
  name  = local.nombre
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = var.puerto
  }

  upload {
    content = local.html
    file    = "/usr/share/nginx/html/index.html"
  }

  dynamic "labels" {
    for_each = local.etiquetas
    content {
      label = labels.key
      value = labels.value
    }
  }
}
