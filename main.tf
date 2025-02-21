terraform {
  backend "s3" {
    bucket = "bucket-alex-iam-lab4"
    key = "terraform.state"
    region = "us-east-1"
    dynamodb_table = "terraform_state_lab4"
  }
}


provider "aws" {
  region = "us-east-1"
}


/////////////////////////////////////////////////////////
//////////////////////S3 + CLOUDFRONT////////////////////
/////////////////////////////////////////////////////////
#  Crear el bucket S3 privado
resource "aws_s3_bucket" "website_bucket" {
  bucket = "mi-bucket-cloudfront"
}

#  Habilitar OAC (Origin Access Control) para CloudFront
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "s3-oac"
  description                       = "OAC para permitir acceso a S3"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

#  Crear CloudFront Distribution
resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name              = aws_s3_bucket.website_bucket.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.website_bucket.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  enabled             = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.website_bucket.id}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

#  Output para ver la URL de CloudFront
output "cloudfront_url" {
  value = aws_cloudfront_distribution.s3_distribution.domain_name
}
/////////////////////////////////////////////////////////
////////////////////FIN S3 + CLOUDFRONT//////////////////
/////////////////////////////////////////////////////////



/////////////////////////////////////////////////////////
///////////////////////////REDES/////////////////////////
/////////////////////////////////////////////////////////
resource "aws_vpc" "lab4-vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "LAB4-VPC"
  }
}

resource "aws_subnet" "public_subnet_a" {
  vpc_id = aws_vpc.lab4-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "LAB4-Public-Subnet-A"
  }
  
}

resource "aws_subnet" "public_subnet_b" {
  vpc_id = aws_vpc.lab4-vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "LAB4-Public-Subnet-B"
  }
  
}

resource "aws_subnet" "private_subnet_a" {
  vpc_id = aws_vpc.lab4-vpc.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "LAB4-Private-Subnet-A"
  }
  
}

resource "aws_subnet" "private_subnet_b" {
  vpc_id = aws_vpc.lab4-vpc.id
  cidr_block = "10.0.4.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "LAB4-Private-Subnet-B"
  }
  
}


resource "aws_internet_gateway" "lab4_igw" {
  vpc_id = aws_vpc.lab4-vpc.id

  tags = {
    Name = "LAB4-IGW"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.lab4-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab4_igw.id
  }

  tags = {
    Name = "LAB4-Public-RT"
  }
}

resource "aws_route_table_association" "public_assoc_a" {
  subnet_id = aws_subnet.public_subnet_a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_assoc_b" {
  subnet_id = aws_subnet.public_subnet_b.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_eip" "nat" {}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_subnet_a.id

  tags = {
    Name = "LAB4-NAT-GW"
  }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.lab4-vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "LAB4-Private-RT"
  }
}

resource "aws_route_table_association" "private_assoc_a" {
  subnet_id      = aws_subnet.private_subnet_a.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_assoc_b" {
  subnet_id      = aws_subnet.private_subnet_b.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_security_group" "lab4_sg" {
  vpc_id = aws_vpc.lab4-vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "LAB4-EC2-SG"
  }
}

resource "aws_security_group" "rds_sg" {
  vpc_id = aws_vpc.lab4-vpc.id

  ingress {
    from_port   = 3306
    to_port     = 3306
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
    Name = "RDS Security Group"
  }
}

resource "aws_iam_role" "ssm_role" {
  name = "LAB4-SSM-Role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "ssm_policy" {
  name       = "ssm-attachment"
  roles      = [aws_iam_role.ssm_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "LAB4-SSM-Profile"
  role = aws_iam_role.ssm_role.id
}

/////////////////////////////////////////////////////////
/////////////////////////FIN REDES///////////////////////
/////////////////////////////////////////////////////////

/////////////////////////////////////////////////////////
////////////////////////////EFS//////////////////////////
/////////////////////////////////////////////////////////
# Crear un EFS
resource "aws_efs_file_system" "efs" {
  creation_token = "efs-lab4"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
}

# Security Group para permitir tráfico NFS
resource "aws_security_group" "efs_sg" {
  name        = "efs-security-group"
  description = "Permite trafico NFS"
  vpc_id      = aws_vpc.lab4-vpc.id # 

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_efs_mount_target" "mount1" {
  file_system_id  = aws_efs_file_system.efs.id
  subnet_id       = aws_subnet.public_subnet_a.id 
  security_groups = [aws_security_group.efs_sg.id]
}
/////////////////////////////////////////////////////////
/////////////////////////FIN EFS/////////////////////////
/////////////////////////////////////////////////////////

/////////////////////////////////////////////////////////
///////////////////////////RDS///////////////////////////
/////////////////////////////////////////////////////////
# Crea un DB Subnet Group para RDS
resource "aws_db_subnet_group" "my_db_subnet_group" {
  name       = "my-db-subnet-group"
  subnet_ids = [aws_subnet.private_subnet_a.id,aws_subnet.private_subnet_b.id]

  tags = {
    Name = "MyDBSubnetGroup"
  }
}

resource "aws_db_instance" "my_rds" {
  identifier             = "mi-base-datos"
  engine                = "mysql"
  engine_version        = "8.0"
  instance_class        = "db.t3.micro"
  allocated_storage     = 20
  storage_type          = "gp2"
  username             = "admin"
  password             = "password123"
  publicly_accessible  = false
  skip_final_snapshot  = true
  db_subnet_group_name = aws_db_subnet_group.my_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id] 

  tags = {
    Name = "MiRDS"
  }
}
/////////////////////////////////////////////////////////
////////////////////////FIN RDS//////////////////////////
/////////////////////////////////////////////////////////


/////////////////////////////////////////////////////////
/////////////////////ELASTIC CACHE///////////////////////
/////////////////////////////////////////////////////////
# Security Group para Elasticache
resource "aws_security_group" "elasticache_sg" {
  name        = "elasticache-security-group"
  description = "Permitir trafico Redis"
  vpc_id      = aws_vpc.lab4-vpc.id

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Subnet Group para Elasticache
resource "aws_elasticache_subnet_group" "cache_subnet" {
  name       = "elasticache-subnet-group"
  subnet_ids = [aws_subnet.private_subnet_a.id, aws_subnet.private_subnet_b.id] 
}

#  Elasticache Redis Cluster
resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "my-redis-cluster"
  engine               = "redis"
  node_type            = "cache.t3.micro" 
  num_cache_nodes      = 1 
  parameter_group_name = "default.redis7"
  engine_version       = "7.0"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.cache_subnet.name
  security_group_ids   = [aws_security_group.elasticache_sg.id]
  apply_immediately    = true
}

output "redis_endpoint" {
  value = aws_elasticache_cluster.redis.cache_nodes[0].address
}


/////////////////////////////////////////////////////////
///////////////////FIN ELASTIC CACHE/////////////////////
/////////////////////////////////////////////////////////
# Crear una instancia EC2 y montar el EFS
resource "aws_instance" "ec2" {
  ami           = "ami-028035e07f51d9b0f" 
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private_subnet_a.id 
  security_groups = [aws_security_group.efs_sg.id]

  user_data = <<-EOF
#!/bin/bash

#MONTANDO EFS
sudo su
yum update -y
yum install -y amazon-efs-utils
mkdir -p /mnt/efs
echo "${aws_efs_file_system.efs.id}:/ /mnt/efs efs defaults,_netdev 0 0" >> /etc/fstab
mount -a

#MONTANDO WORDPRESS
yes | yum install httpd.x86_64
sudo yum install -y php php-cli php-mysqlnd php-xml php-mbstring php-curl php-json php-zip
sudo systemctl start httpd
sudo systemctl enable httpd
cd /var/www
wget https://wordpress.org/latest.zip
unzip latest.zip
sudo mv wordpress/* /var/www/html/
sudo chmod -R 755 /var/www/html/
rm -f latest.zip
rm -rf wordpress

#UNIENDO POSTGRES A WORDPRESS
cd /var/www
wget https://github.com/PostgreSQL-For-Wordpress/postgresql-for-wordpress/archive/refs/tags/v3.4.1.zip
unzip v3.4.1.zip
mv postgresql*/pg4wp html/wp-content
cp html/wp-content/pg4wp/db.php html/wp-content
rm -f v3.4.1.zip
rm -rf postgresql*
vim html/wp-config-sample.php
mv html/wp-config-sample.php html/wp-config.php

#ABRIENDO EL PUERTO 443
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/pki/tls/private/tuclave.key -out /etc/pki/tls/certs/tucertificado.crt
sudo yum install -y mod_ssl
#sudo vim /etc/httpd/conf/httpd.conf (pongo el listener en 443, en la linea: "Listener", hago el "sudo systemctl restart httpd" y me sale error.
EOF

  tags = {
    Name = "EC2-with-EFS"
  }
}

output "efs_id" {
  value = aws_efs_file_system.efs.id
}

output "ec2_ip" {
  value = aws_instance.ec2.public_ip
}


/////////////////////////////////////////////////////////
///////////////////////////ASG///////////////////////////
/////////////////////////////////////////////////////////

#  Crea una imagen AMI a partir de la EC2 existente
resource "aws_ami_from_instance" "wordpress_ami" {
  name               = "wordpress-image-${formatdate("YYYYMMDD-HHmmss", timestamp())}"
  source_instance_id = aws_instance.ec2.id
  snapshot_without_reboot = true
}

#  Crea un Launch Template con la AMI generada
resource "aws_launch_template" "wordpress_template" {
  name_prefix   = "wordpress-launch-template-"
  image_id      = aws_ami_from_instance.wordpress_ami.id
  instance_type = "t2.micro"

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.efs_sg.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "Wordpress-Auto-Scaling"
    }
  }
}

#  Crea Auto Scaling Group con 2-3 instancias
resource "aws_autoscaling_group" "wordpress_asg" {
  desired_capacity     = 2
  max_size            = 3
  min_size            = 2
  vpc_zone_identifier = [aws_subnet.private_subnet_a.id, aws_subnet.public_subnet_a.id] 
  launch_template {
    id      = aws_launch_template.wordpress_template.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "Wordpress-ASG"
    propagate_at_launch = true
  }
}

# Crea un Load Balancer para distribuir tráfico
resource "aws_lb" "wordpress_lb" {
  name               = "wordpress-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.efs_sg.id]
  subnets           = [aws_subnet.private_subnet_a.id, aws_subnet.public_subnet_a.id]

  enable_deletion_protection = false
}

# Crea Target Group para el Load Balancer
resource "aws_lb_target_group" "wordpress_tg" {
  name     = "wordpress-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.lab4-vpc.id
}

# Asocia ASG con Target Group
resource "aws_autoscaling_attachment" "asg_attachment" {
  autoscaling_group_name = aws_autoscaling_group.wordpress_asg.id
  lb_target_group_arn    = aws_lb_target_group.wordpress_tg.arn
}

# Crea un Listener para el Load Balancer
resource "aws_lb_listener" "wordpress_listener" {
  load_balancer_arn = aws_lb.wordpress_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wordpress_tg.arn
  }
}

output "load_balancer_url" {
  value = aws_lb.wordpress_lb.dns_name
}


/////////////////////////////////////////////////////////
////////////////////////FIN ASG//////////////////////////
/////////////////////////////////////////////////////////

/////////////////////////////////////////////////////////
////////////////////////ROUTE53//////////////////////////
/////////////////////////////////////////////////////////

#  Crea Zona en Route 53 para "pepita.com"
resource "aws_route53_zone" "pepita_com" {
  name = "pepita.com"
}

# Crea un Registro CNAME para el ALB
resource "aws_route53_record" "alb_cname" {
  zone_id = aws_route53_zone.pepita_com.zone_id  # ID de la zona de Route 53
  name    = "alb.pepita.com"  # Subdominio que apuntará al ALB
  type    = "CNAME"
  ttl     = 300  # Tiempo de vida del DNS en segundos (5 min)
  records = [aws_lb.wordpress_lb.dns_name]  #  Usa el DNS del ALB
}

/////////////////////////////////////////////////////////
//////////////////////FIN ROUTE53////////////////////////
/////////////////////////////////////////////////////////
