variable "nombre" {
  description = "Nombre del contenedor del sitio"
  type        = string
}

variable "mensaje" {
  description = "Mensaje que muestra la página principal del sitio"
  type        = string
}

variable "imagen" {
  description = "Imagen de nginx a desplegar"
  type        = string
  default     = "nginx:1.28-alpine"
}

variable "puerto" {
  description = "Puerto externo del sitio"
  type        = number

  validation {
    condition     = var.puerto >= 8000 && var.puerto <= 8999
    error_message = "El puerto debe estar entre 8000 y 8999."
  }
}
