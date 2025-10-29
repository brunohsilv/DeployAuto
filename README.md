# 🚀 WordPress Automated Deployment

Deploy automatizado do WordPress na AWS usando Terraform, Ansible e Docker.

## ✨ Características

- ✅ **Infraestrutura como Código** (Terraform)
- ✅ **Configuração automatizada** (Ansible) 
- ✅ **Containerizado** (Docker Compose)
- ✅ **Free Tier** (t3.micro, 8GB EBS)
- ✅ **1 comando para deploy completo**

## 🛠️ Pré-requisitos

### Instalação das ferramentas:

```bash
# Terraform (Linux/WSL)
curl -fsSL https://releases.hashicorp.com/terraform/1.7.7/terraform_1.7.7_linux_amd64.zip -o terraform.zip \
&& unzip terraform.zip \
&& sudo mv terraform /usr/local/bin/ \
&& rm terraform.zip

# Ansible
sudo apt install ansible

# AWS CLI (Linux x86_64)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
sudo apt install unzip
unzip awscliv2.zip
sudo ./aws/install
````

Configurar credencias: ```aws configure```
(As credencias são geradas pelo IAM da AWS)

# Para realizar o Deploy

```
chmod +x check-prerequisites.sh deploy.sh
./check-prerequisites.sh    # Verifica dependências
./deploy.sh                 # Deploy automático
```
