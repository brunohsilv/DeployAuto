terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "sa-east-1"
}

data "aws_ssm_parameter" "ubuntu_ami" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

# 🔑 NOVO: Gerador de chave SSH dinâmico
resource "tls_private_key" "wordpress_key" {
  count     = var.create_ssh_key ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

# 🔑 NOVO: Salvar chave privada localmente
resource "local_file" "private_key" {
  count    = var.create_ssh_key ? 1 : 0
  content  = tls_private_key.wordpress_key[0].private_key_pem
  filename = "${path.module}/wordpress-key.pem"
  
  file_permission = "0400"  # Apenas leitura para o dono
}

# 🔑 MODIFICADO: Key pair dinâmico
resource "aws_key_pair" "wordpress" {
  key_name   = "wordpress-key-${formatdate("YYYYMMDD", timestamp())}"
  public_key = var.create_ssh_key ? tls_private_key.wordpress_key[0].public_key_openssh : file(var.ssh_public_key_path)
}

# 🏷️ NOVO: Local para determinar qual chave usar
locals {
  ssh_key_path = var.create_ssh_key ? "${path.module}/wordpress-key.pem" : var.ssh_public_key_path
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "wordpress-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "wordpress-igw"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "sa-east-1a"

  tags = {
    Name = "wordpress-public-subnet"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "wordpress-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "wordpress" {
  name        = "wordpress-sg"
  description = "Allow HTTP, HTTPS and SSH traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "wordpress-sg"
  }
}

resource "aws_instance" "wordpress" {
  ami                    = data.aws_ssm_parameter.ubuntu_ami.value
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.wordpress.key_name
  vpc_security_group_ids = [aws_security_group.wordpress.id]
  subnet_id              = aws_subnet.public.id
  user_data              = filebase64("user_data.sh")

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }

  tags = {
    Name = "wordpress-server"
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_eip" "wordpress" {
  instance = aws_instance.wordpress.id
  domain   = "vpc"

  tags = {
    Name = "wordpress-eip"
  }
}