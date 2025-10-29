variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "sa-east-1"
}

variable "ssh_public_key_path" {
  description = "Path to existing SSH public key. Ignored if create_ssh_key is true"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "create_ssh_key" {
  description = "Whether to create a new SSH key pair for this project"
  type        = bool
  default     = true  # ← Agora cria chave específica por padrão!
}