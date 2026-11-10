locals {
  entorno = terraform.workspace

  ambientes = {
    dev     = { base_puerto = 8100, sitios = ["tienda"], imagen = "nginx:1.28-alpine" }
    staging = { base_puerto = 8200, sitios = ["tienda", "blog", "docs"], imagen = "nginx:1.28-alpine" }
    prod    = { base_puerto = 8300, sitios = ["tienda", "blog", "docs"], imagen = "nginx:1.27-alpine" }
  }

  # Falla a propósito en el workspace "default": obliga a elegir un ambiente
  amb = local.ambientes[local.entorno]

  desplazamiento = { tienda = 1, blog = 2, docs = 3 }

  sitios = {
    for s in local.amb.sitios : s => local.amb.base_puerto + local.desplazamiento[s]
  }

  etiquetas = {
    curso = "arquitectura-sw-2"
    grupo = tostring(var.grupo)
  }
}
