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
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Ansible
sudo apt install ansible

# AWS CLI (Linux x86_64)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
sudo apt install unzip
unzip awscliv2.zip
sudo ./aws/install
````
Configurar credencias: ```aws configure```
(As credencias são geradas pelo IMA da AWS)

# Para realizar o Deploy

```
chmod +x check-prerequisites.sh deploy.sh
./check-prerequisites.sh    # Verifica dependências
./deploy.sh                 # Deploy automático
```
