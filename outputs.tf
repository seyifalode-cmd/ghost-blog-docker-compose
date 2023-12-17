#-----outputs.tf-----
#====================
output "Sever-Public-IP" {
  value = "${module.compute.server_ip}"
}
