#!/bin/bash

EFS_DNS="<EFS_DNS>"
EFS_DIR="/mnt/efs"

WORDPRESS_DIR="/home/ec2-user/wordpress"

yum update -y
yum install -y aws-cli

yum install -y docker
service docker start
systemctl enable docker
usermod -a -G docker ec2-user

curl -SL https://github.com/docker/compose/releases/download/v2.34.0/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

yum install -y amazon-efs-utils
mkdir -p ${EFS_DIR}
mount -t efs ${EFS_DNS}:/ ${EFS_DIR}
echo "${EFS_DNS}:/ ${EFS_DIR} efs defaults,_netdev 0 0" >> /etc/fstab

chown -R 33:33 ${EFS_DIR}

mkdir -p ${WORDPRESS_DIR}
cd ${WORDPRESS_DIR}

cat > docker-compose.yml <<EOF
version: '3.7'
services:
  wordpress:
    image: wordpress:latest
    container_name: wordpress
    ports:
      - 80:80
    volumes:
      - ${EFS_DIR}:/var/www/html
    environment:
      WORDPRESS_DB_HOST: <DB_HOST>
      WORDPRESS_DB_NAME: <DB_NAME>
      WORDPRESS_DB_USER: <DB_USER>
      WORDPRESS_DB_PASSWORD: <DB_PASSWORD>

EOF

docker-compose up -d
