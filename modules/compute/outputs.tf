#-----compute/outputs.tf-----
#=============================
output "server_id" {
  value =  aws_instance.docker.id
}

output "server_ip" {
  value = aws_instance.docker.public_ip
}
