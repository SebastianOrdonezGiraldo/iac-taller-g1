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

module "tienda" {
  source  = "./modules/sitio_web"
  nombre  = "tienda-g${var.grupo}"
  puerto  = 8081
  mensaje = "Tienda del grupo ${var.grupo}"
  imagen  = var.imagen
}

module "blog" {
  source  = "./modules/sitio_web"
  nombre  = "blog-g${var.grupo}"
  puerto  = 8082
  mensaje = "Blog del grupo ${var.grupo}"
  imagen  = var.imagen
}

module "docs" {
  source  = "./modules/sitio_web"
  nombre  = "docs-g${var.grupo}"
  puerto  = 8083
  mensaje = "Documentación del grupo ${var.grupo}"
  imagen  = var.imagen
}
