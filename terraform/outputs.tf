output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_eip.wordpress.public_ip
}

output "instance_url" {
  description = "WordPress URL"
  value       = "http://${aws_eip.wordpress.public_ip}"
}

output "ssh_private_key_path" {
  description = "Path to the SSH private key for connecting to the instance"
  value       = var.create_ssh_key ? "${path.module}/wordpress-key.pem" : var.ssh_public_key_path
  sensitive   = true
}

output "key_created" {
  description = "Whether a new SSH key was created"
  value       = var.create_ssh_key
}