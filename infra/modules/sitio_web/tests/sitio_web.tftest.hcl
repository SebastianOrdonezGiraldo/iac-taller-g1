# En Windows el provider necesita la ruta del motor de Docker
provider "docker" {
  host = "npipe:////.//pipe//docker_engine"
}

variables {
  nombre  = "prueba-g1"
  puerto  = 8999
  mensaje = "Prueba automatizada"
  imagen  = "nginx:1.28-alpine"
}

run "url_coherente_con_puerto" {
  command = plan

  assert {
    condition     = output.url == "http://localhost:8999"
    error_message = "La URL no corresponde al puerto configurado."
  }
}

run "rechaza_puerto_fuera_de_rango" {
  command = plan

  variables {
    puerto = 9500
  }

  expect_failures = [var.puerto]
}

run "despliegue_real" {
  # Sin "command": crea el sitio de verdad y lo destruye al terminar

  assert {
    condition     = docker_container.this.name == "prueba-g1"
    error_message = "El contenedor no quedó con el nombre esperado."
  }
}

run "nombre_coincide_con_variable" {
  command = plan

  assert {
    condition     = output.nombre == var.nombre
    error_message = "El output nombre no coincide con var.nombre."
  }
}
