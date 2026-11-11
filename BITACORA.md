# Bitácora — Taller IaC con Terraform

**Curso:** Arquitectura de Software II · 2026-2
**Grupo:** 1

## Integrantes

- Sebastián Ordoñez Giraldo
- Jerónimo Rodríguez
- Jerónimo Vallejo
- Carlos Arturo Barón

## Rotación de roles

| Fase | Operador/a | Navegante | Revisor/a del plan | Bitácora |
|------|------------|-----------|--------------------|----------|
| 0 y 1 |  |  |  |  |
| 2 |  |  |  |  |
| 3 |  |  |  |  |
| 4 |  |  |  |  |
| 5 |  |  |  |  |
| 6 |  |  |  |  |
| 7 |  |  |  |  |
| 8 |  |  |  |  |
| 9 |  |  |  |  |

---

## Fase 0 · Preparación del entorno

### Evidencias

Salida completa: `evidencias/fase-0/herramientas.txt, evidencias/fase-0/imagenes.txt`

```text
> terraform -version
Terraform v1.17.0
> docker version
Client:
 Version:           29.9.2
Server: Docker Desktop 4.97.0 (244584)
> git --version
git version 2.47.1.windows.2
```

### Respuestas

---

## Fase 1 · Arranque: hacerlo a mano

### Evidencias

Salida completa: `evidencias/fase-1/clickops.txt`

```text
> docker run -d --name clickops-g1 -p 8090:80 nginx:1.27-alpine
80601145b68ae89adc8b20f792ea87ccbc797b72b2e8cf87d51b6d62aa54b808
> GET http://localhost:8090
<h1>Welcome to nginx!</h1>
> docker run -d --name clickops-g1 -p 8090:80 nginx:1.27-alpine
docker: Error response from daemon: Conflict. The container name "/clickops-g1" is already in use by container "80601145b68ae89adc8b20f792ea87ccbc797b72b2e8cf87d51b6d62aa54b808". You have to remove (or rename) that container to be able to reuse that name.
> docker run -d --name clickops-g1-2 -p 8090:80 nginx:1.27-alpine
3adb0b11f52205132fd8575e4237aa8dddbfdc38bc2966048c763e8bf65e2a5e
docker: Error response from daemon: failed to set up container networking: driver failed programming external connectivity on endpoint clickops-g1-2 (9f12a90d3478cb0196e0d3b52cc4ede1a97b1b6309146a7b1cb2344d7e0d9194): Bind for 0.0.0.0:8090 failed: port is already allocated
> docker rm -f clickops-g1 clickops-g1-2
clickops-g1
clickops-g1-2
> docker ps -a
```

### Respuestas

---

## Fase 2 · Primer despliegue: write → init → plan → apply

### Evidencias

Salida completa: `evidencias/fase-2/ciclo.txt, evidencias/fase-2/git-status.txt`

```text
> terraform init -no-color
- Installed kreuzwerker/docker v4.6.0 (self-signed, key ID 0DCE698927DAF8EC)
> terraform fmt
> terraform validate -no-color
Success! The configuration is valid.
> terraform plan -no-color -out fase2.tfplan
      + name                                        = "web-g1"
Plan: 2 to add, 0 to change, 0 to destroy.
Revision del plan: aprobado
> terraform apply -no-color fase2.tfplan
Apply complete! Resources: 2 added, 0 changed, 0 destroyed.
url = "http://localhost:8080"
> terraform output -no-color
url = "http://localhost:8080"
> GET http://localhost:8080
<h1>Welcome to nginx!</h1>
> docker ps --filter name=web-g1
d0f23edaaaf7   65645c7bb6a0   "/docker-entrypoint.ΓÇª"   1 second ago   Up Less than a second   0.0.0.0:8080->80/tcp   web-g1
```

### Respuestas

---

## Fase 3 · Idempotencia y estado

### Evidencias

Salida completa: `evidencias/fase-3/idempotencia-y-estado.txt`

```text
> terraform apply -no-color -input=false
docker_image.nginx: Refreshing state... [id=sha256:65645c7bb6a0661892a8b03b89d0743208a18dd2f3f17a54ef4b76fb8e2f2a10nginx:1.27-alpine]
docker_container.web: Refreshing state... [id=d0f23edaaaf75c1b9faea455c8e3606e2038e37494acf0f3e773dca3a38f7e4c]
No changes. Your infrastructure matches the configuration.
Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
> terraform state list
docker_container.web
docker_image.nginx
> terraform state show -no-color docker_container.web
serial = 4
lineage = 2f5f8ce9-86b0-1c44-df2d-7564b9f6f853
resources = docker_container.web, docker_image.nginx
> terraform plan -no-color -out fase3.tfplan
docker_image.nginx: Refreshing state... [id=sha256:65645c7bb6a0661892a8b03b89d0743208a18dd2f3f17a54ef4b76fb8e2f2a10nginx:1.27-alpine]
docker_container.web: Refreshing state... [id=d0f23edaaaf75c1b9faea455c8e3606e2038e37494acf0f3e773dca3a38f7e4c]
      ~ image                                       = "sha256:65645c7bb6a0661892a8b03b89d0743208a18dd2f3f17a54ef4b76fb8e2f2a10" -> (known after apply) # forces replacement
      ~ name         = "nginx:1.27-alpine" -> "nginx:1.28-alpine" # forces replacement
Plan: 2 to add, 0 to change, 2 to destroy.
Revision del plan: aprobado
> terraform apply -no-color fase3.tfplan
docker_container.web: Destroying... [id=d0f23edaaaf75c1b9faea455c8e3606e2038e37494acf0f3e773dca3a38f7e4c]
docker_container.web: Destruction complete after 0s
docker_image.nginx: Destroying... [id=sha256:65645c7bb6a0661892a8b03b89d0743208a18dd2f3f17a54ef4b76fb8e2f2a10nginx:1.27-alpine]
docker_image.nginx: Destruction complete after 0s
docker_image.nginx: Creating...
docker_image.nginx: Creation complete after 1s [id=sha256:a8b39bd9cf0f83869a2162827a0caf6137ddf759d50a171451b335cecc87d236nginx:1.28-alpine]
docker_container.web: Creating...
docker_container.web: Creation complete after 1s [id=dd1315238d73c832a35d2e8745da9eb35d4e739429e98ee0bb219a406965017b]
Apply complete! Resources: 2 added, 0 changed, 2 destroyed.
> GET http://localhost:8080
> terraform plan -no-color
docker_image.nginx: Refreshing state... [id=sha256:a8b39bd9cf0f83869a2162827a0caf6137ddf759d50a171451b335cecc87d236nginx:1.28-alpine]
docker_container.web: Refreshing state... [id=dd1315238d73c832a35d2e8745da9eb35d4e739429e98ee0bb219a406965017b]
No changes. Your infrastructure matches the configuration.
serial = 9
lineage = 2f5f8ce9-86b0-1c44-df2d-7564b9f6f853
resources = docker_container.web, docker_image.nginx
```

### Respuestas

---

## Fase 4 · Drift: cuando la realidad se desvía

### Evidencias

Salida completa: `evidencias/fase-4/A-apagar.txt, B-borrar.txt, C-cambiar-por-dentro.txt`

```text
=== Experimento A: apagar el servidor ===
> docker stop web-g1
> terraform plan -no-color -out fase4a.tfplan
  # docker_container.web must be replaced
      ~ must_run                                    = false -> true
Plan: 1 to add, 0 to change, 1 to destroy.
Revision del plan: aprobado
> terraform apply -no-color fase4a.tfplan
Apply complete! Resources: 1 added, 0 changed, 1 destroyed.
> GET http://localhost:8080
<h1>Welcome to nginx!</h1>
=== Experimento B: borrar el servidor ===
> docker rm -f web-g1
> terraform plan -no-color -refresh-only
  # docker_container.web has been deleted
      - must_run                                    = true -> null
> terraform plan -no-color -out fase4b.tfplan
  # docker_container.web will be created
      + must_run                                    = true
Plan: 1 to add, 0 to change, 0 to destroy.
Revision del plan: aprobado
> terraform apply -no-color fase4b.tfplan
Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
> GET http://localhost:8080
<h1>Welcome to nginx!</h1>
=== Experimento C: cambiar el contenido por dentro ===
> docker exec web-g1 sh -c "echo '<h1>Cambio manual</h1>' > /usr/share/nginx/html/index.html"
> GET http://localhost:8080
<h1>Cambio manual</h1>
> terraform plan -no-color
No changes. Your infrastructure matches the configuration.
> terraform plan -no-color -replace=docker_container.web -out fase4c.tfplan
Revision del plan: aprobado
> terraform apply -no-color fase4c.tfplan
> GET http://localhost:8080
<h1>Cambio manual</h1>
> terraform plan -no-color
No changes. Your infrastructure matches the configuration.
=== Reintento de la correccion inmutable (el argumento -replace necesitaba comillas en PowerShell) ===
> GET http://localhost:8080
<h1>Cambio manual</h1>
> terraform plan -no-color "-replace=docker_container.web" -out fase4c.tfplan
  # docker_container.web will be replaced, as requested
Plan: 1 to add, 0 to change, 1 to destroy.
Revision del plan: aprobado
> terraform apply -no-color fase4c.tfplan
Apply complete! Resources: 1 added, 0 changed, 1 destroyed.
> GET http://localhost:8080
<h1>Welcome to nginx!</h1>
> terraform plan -no-color
No changes. Your infrastructure matches the configuration.
```

### Respuestas

| Experimento | ¿El plan lo detectó? | ¿Qué propuso Terraform? | ¿Cómo quedó corregido? |
|---|---|---|---|
| A · Apagar |  |  |  |
| B · Borrar |  |  |  |
| C · Cambiar por dentro |  |  |  |

---

## Fase 5 · Las piezas que dan flexibilidad

### Evidencias

Salida completa: `evidencias/fase-5/flexibilidad.txt`

```text
> Get-ChildItem -Name
> terraform fmt
> terraform validate -no-color
> terraform plan -no-color -out fase5.tfplan
          + label = "curso"
                <h1>Hola desde el grupo 1</h1>
Plan: 1 to add, 0 to change, 1 to destroy.
Revision del plan: aprobado
> terraform apply -no-color fase5.tfplan
Apply complete! Resources: 1 added, 0 changed, 1 destroyed.
contenedor = "web-g1"
red_driver = "bridge"
url = "http://localhost:8080"
> GET http://localhost:8080
<h1>Hola desde el grupo 1</h1>
> terraform output -no-color
contenedor = "web-g1"
red_driver = "bridge"
url = "http://localhost:8080"
> local.nombre
"web-g1"
> upper(var.mensaje)
"HOLA DESDE EL GRUPO 1"
> format("web-g%02d", var.grupo)
"web-g01"
> local.etiquetas
  "curso" = "arquitectura-sw-2"
  "grupo" = "1"
> data.docker_network.bridge.driver
"bridge"
> terraform plan -no-color "-var=puerto=9500"
Error: Invalid value for variable
El puerto debe estar entre 8000 y 8999.
> terraform plan -no-color "-var=puerto=8085"
Plan: 1 to add, 0 to change, 1 to destroy.
> terraform plan -no-color
No changes. Your infrastructure matches the configuration.
```

### Respuestas

---

## Fase 6 · Módulos: la receta una sola vez

### Evidencias

Salida completa: `evidencias/fase-6/modulos.txt`

```text
> Get-ChildItem -Recurse -Name -Include *.tf,*.tfvars
> terraform init -no-color
> terraform fmt -recursive
> terraform validate -no-color
> terraform plan -no-color -out fase6.tfplan
Plan: 6 to add, 0 to change, 2 to destroy.
  - url        = "http://localhost:8080" -> null
      + "http://localhost:8081",
      + "http://localhost:8082",
      + "http://localhost:8083",
Revision del plan: aprobada
> terraform apply -no-color fase6.tfplan
Apply complete! Resources: 6 added, 0 changed, 2 destroyed.
  "http://localhost:8081",
  "http://localhost:8082",
  "http://localhost:8083",
> GET http://localhost:8081
<h1>Tienda del grupo 1</h1>
> GET http://localhost:8082
<h1>Blog del grupo 1</h1>
> GET http://localhost:8083
<h1>DocumentaciÃ³n del grupo 1</h1>
> terraform output -no-color urls
  "http://localhost:8081",
  "http://localhost:8082",
  "http://localhost:8083",
> docker ps --filter name=-g1
> terraform plan -no-color
No changes. Your infrastructure matches the configuration.
```

### Respuestas

---

## Fase 7 · State remoto y varios ambientes

### Evidencias

Salida completa: `evidencias/fase-7/A-state-remoto.txt, B-ambientes.txt, C-prueba-bloqueo.txt`

```text
=== Parte A, paso 1: backend PostgreSQL (fuera de Terraform) ===
> docker run -d --name tf-state-g1 -e POSTGRES_USER=terraform -e POSTGRES_PASSWORD=******** -e POSTGRES_DB=terraform_backend -p 5433:5432 postgres:17-alpine
> docker exec tf-state-g1 pg_isready -U terraform -d terraform_backend
=== Paso 2: conexion en variable de entorno (solo en esta terminal) ===
=== Paso 3: backend pg vacio en main.tf ===
> Select-String -Path main.tf -Pattern 'backend'
=== Paso 4: migrar el state (-force-copy responde yes) ===
> terraform init -no-color -migrate-state -force-copy
Successfully configured the backend "pg"! Terraform will automatically
> terraform state list
> docker exec tf-state-g1 psql -U terraform -d terraform_backend -c "SELECT id, name FROM terraform_remote_state.states;"
  1 | default
=== Paso 5: prueba de bloqueo con dos terminales ===
Terminal 1: terraform apply -replace=module.tienda.docker_container.this (queda esperando confirmacion)
Terminal 2:
> terraform plan -no-color -lock-timeout=0s
Nota: en este primer intento la terminal 2 NO encontro el bloqueo (no se pudo confirmar en que estado estaba la terminal 1 en ese momento). La prueba se repitio con verificacion en C-prueba-bloqueo.txt.
> terraform plan -no-color
=== Parte B, paso 6: destroy del workspace default ===
> terraform plan -no-color -destroy -out fase7-destroy.tfplan
Plan: 0 to add, 0 to change, 6 to destroy.
Revision del plan: aprobado
> terraform apply -no-color fase7-destroy.tfplan
Apply complete! Resources: 0 added, 0 changed, 6 destroyed.
=== Pasos 7-8: ambientes en locals.tf y module sitio con for_each ===
> terraform fmt -recursive
=== Paso 9: init y prueba en el workspace default (debe fallar) ===
> terraform init -no-color
> terraform plan -no-color
Error: Invalid index
=== Workspace dev ===
> terraform workspace new dev
> terraform workspace show
> terraform plan -no-color -out fase7-dev.tfplan
Plan: 2 to add, 0 to change, 0 to destroy.
Revision del plan: "aprobado"
=== Reanudacion: el apply de dev se cancelo en la revision; se retoma desde dev ===
=== Workspace dev ===
> terraform workspace show
> terraform plan -no-color -out fase7-dev.tfplan
Plan: 2 to add, 0 to change, 0 to destroy.
Revision del plan: aprobado
> terraform apply -no-color fase7-dev.tfplan
Apply complete! Resources: 2 added, 0 changed, 0 destroyed.
=== Workspace staging ===
> terraform workspace new staging
> terraform workspace show
> terraform plan -no-color -out fase7-staging.tfplan
Plan: 6 to add, 0 to change, 0 to destroy.
Revision del plan: aprobado
> terraform apply -no-color fase7-staging.tfplan
Apply complete! Resources: 6 added, 0 changed, 0 destroyed.
=== Workspace prod ===
> terraform workspace new prod
> terraform workspace show
> terraform plan -no-color -out fase7-prod.tfplan
Plan: 6 to add, 0 to change, 0 to destroy.
Revision del plan: aprobado
> terraform apply -no-color fase7-prod.tfplan
Apply complete! Resources: 6 added, 0 changed, 0 destroyed.
> terraform workspace list
> GET http://localhost:8101
<h1>Tienda - DEV - grupo 1</h1>
> GET http://localhost:8201
<h1>Tienda - STAGING - grupo 1</h1>
> GET http://localhost:8202
<h1>Blog - STAGING - grupo 1</h1>
> GET http://localhost:8203
<h1>Docs - STAGING - grupo 1</h1>
> GET http://localhost:8301
<h1>Tienda - PROD - grupo 1</h1>
> GET http://localhost:8302
<h1>Blog - PROD - grupo 1</h1>
> GET http://localhost:8303
<h1>Docs - PROD - grupo 1</h1>
> docker exec tf-state-g1 psql -U terraform -d terraform_backend -c "SELECT id, name FROM terraform_remote_state.states;"
  1 | default
  4 | dev
  6 | staging
  8 | prod
(4 rows)
> docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}' --filter name=-g1
=== Verificacion: la contrasena no esta en el repositorio ===
git grep <contrasena del backend>: sin coincidencias
=== Prueba de bloqueo con dos terminales (workspace dev) ===
> terraform workspace show
Terminal 1: terraform apply -var=grupo=2 (cambio pendiente; queda esperando confirmacion y no se aplica)
Terminal 2 (intento 1):
Plan: 1 to add, 0 to change, 1 to destroy.
Terminal 2 (intento 2):
Plan: 1 to add, 0 to change, 1 to destroy.
Terminal 2 (intento 3):
Plan: 1 to add, 0 to change, 1 to destroy.
=== Incidente: en la terminal 1 se confirmo el apply (-var=grupo=2) en lugar de cancelarlo ===
El contenedor de dev quedo como tienda-g2-dev; por eso la terminal 2 no encontro bloqueo. Se corrige volviendo al codigo.
> terraform workspace show
> terraform plan -no-color -out fase7-fix.tfplan
Error: dial tcp 127.0.0.1:5433: connectex: No connection could be made because the target machine actively refused it.
Revision del plan: aprobada
> terraform apply -no-color fase7-fix.tfplan
Error: Failed to load "fase7-fix.tfplan" as a plan file
Error: GetFileAttributesEx fase7-fix.tfplan: The system cannot find the file
=== Prueba de bloqueo, nuevo intento ===
Terminal 1: terraform console (mantiene el bloqueo del state mientras esta abierta; no puede aplicar cambios)
=== Incidente: en la terminal 1 se confirmo el apply (-var=grupo=2) en lugar de cancelarlo ===
El contenedor de dev quedo como tienda-g2-dev; por eso la terminal 2 no encontro bloqueo. Se corrige volviendo al codigo.
> terraform workspace show
> terraform plan -no-color -out fase7-fix.tfplan
Plan: 1 to add, 0 to change, 1 to destroy.
Revision del plan: aprobada
> terraform apply -no-color fase7-fix.tfplan
Apply complete! Resources: 1 added, 0 changed, 1 destroyed.
=== Prueba de bloqueo, nuevo intento ===
Terminal 1: terraform console (mantiene el bloqueo del state mientras esta abierta; no puede aplicar cambios)
Terminal 2 (intento 1):
Nota: terraform console no adquiere el bloqueo del state (solo lo lee); por eso ese intento no sirvio. Se vuelve al apply que pide la guia.
=== Prueba de bloqueo con apply (workspace dev) ===
> terraform workspace show
Terminal 1: terraform apply -replace=module.sitio["tienda"].docker_container.this (queda esperando confirmacion; si se aplicara solo recrearia el mismo contenedor)
Terminal 2 (intento 1):
Error: Error acquiring the state lock
Error message: Workspace is already locked: dev
Terminal 1 (confirmado por el grupo): listo - respondio 'no' y el apply se cancelo.
=== Verificacion: bloqueo liberado y dev igual al codigo ===
> terraform plan -no-color -lock-timeout=0s
```

### Respuestas

---

## Fase 8 · Testing y calidad

### Evidencias

Salida completa: `evidencias/fase-8/1-analisis-estatico.txt, 2-terraform-test.txt, 2-docker-ps-durante-test.txt, 3-escaneo-seguridad.txt, 4-validar-sh.txt`

```text
> terraform workspace show
> terraform fmt -check -recursive
> terraform validate -no-color
Success! The configuration is valid.
14:36:13  prueba-g1 Up Less than a second 0.0.0.0:8999->80/tcp
> terraform init -no-color
> terraform test -no-color
  run "url_coherente_con_puerto"... pass
  run "rechaza_puerto_fuera_de_rango"... pass
  run "despliegue_real"... pass
  run "nombre_coincide_con_variable"... pass
tests\sitio_web.tftest.hcl... pass
Success! 4 passed, 0 failed.
=== Escaneo con el bucket publico (cuatro valores en false) ===
> python -m checkov.main -d seguridad --compact --quiet
Passed checks: 4, Failed checks: 11, Skipped checks: 0
=== Correccion: los cuatro valores a true ===
> Get-Content seguridad\bucket.tf
=== Escaneo despues de corregir ===
> python -m checkov.main -d seguridad --compact --quiet
Passed checks: 9, Failed checks: 6, Skipped checks: 0
=== Resumen antes / despues ===
Passed checks: 4, Failed checks: 11, Skipped checks: 0
Passed checks: 9, Failed checks: 6, Skipped checks: 0
=== Ejecucion normal ===
> bash validar.sh   (todo correcto)
Success! The configuration is valid.
Success! 4 passed, 0 failed.
Passed checks: 4, Failed checks: 0, Skipped checks: 0
Validación completa: el cambio puede pasar a revisión
Codigo de salida: 0
=== Prueba: indentacion desordenada en infra/outputs.tf ===
> bash validar.sh   (fmt desordenado)
Codigo de salida: 3
=== Prueba: un valor del bucket de nuevo en false ===
> bash validar.sh   (bucket publico)
Codigo de salida: 3
=== Ejecucion final con todo restaurado ===
> bash validar.sh   (restaurado)
Codigo de salida: 3
=== Correccion: al restaurar infra/outputs.tf el script anterior le agrego un BOM (UTF-8), por eso fmt -check seguia fallando en las dos ultimas ejecuciones. Se quito el BOM y se repiten. ===
=== Prueba: un valor del bucket de nuevo en false ===
> bash validar.sh   (bucket publico)
Success! The configuration is valid.
Success! 4 passed, 0 failed.
Passed checks: 3, Failed checks: 1, Skipped checks: 0
Codigo de salida: 1
=== Ejecucion final con todo restaurado ===
> bash validar.sh   (restaurado)
Success! The configuration is valid.
Success! 4 passed, 0 failed.
Passed checks: 4, Failed checks: 0, Skipped checks: 0
Validación completa: el cambio puede pasar a revisión
Codigo de salida: 0
```

### Respuestas

---

## Fase 9 · Auditoría cruzada y cierre

### Evidencias

### Respuestas
