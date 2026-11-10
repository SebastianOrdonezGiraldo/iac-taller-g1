variable "grupo" {
  description = "Número del grupo"
  type        = number
}

variable "imagen" {
  description = "Imagen de nginx a desplegar"
  type        = string
  default     = "nginx:1.28-alpine"
}
