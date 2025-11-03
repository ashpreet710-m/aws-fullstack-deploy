output "frontend_instance_public_ip" {
  value = aws_instance.frontend.public_ip
}
output "backend_instance_public_ips" {
  value = [for i in aws_instance.backend: i.public_ip]
}
