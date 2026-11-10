# Lee la red "bridge" que Docker ya tiene; no la crea
data "docker_network" "bridge" {
  name = "bridge"
}
