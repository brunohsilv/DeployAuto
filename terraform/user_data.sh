#!/bin/bash
# Script de inicialização - prepara sistema para Ansible
apt-get update
apt-get install -y python3 python3-pip
echo "User data completed" > /tmp/user_data_completed