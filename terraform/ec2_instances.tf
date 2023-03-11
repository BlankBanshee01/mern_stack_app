# Defining the provider
provider "aws" {
  region = var.region_name
}

# Defining security group
resource "aws_security_group" "allow_all" {
  name        = "allow_all"
  description = "Allow all traffic"

  ingress {
    from_port        = 0
    to_port          = 0
    protocol         = "all"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "all"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_all_traffic"
  }
}

# Creating a private/pub key
resource "tls_private_key" "ec2-k8s-key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Creating the EC2 key pair
resource "aws_key_pair" "tf-k8s" {
  key_name   = "k8s-ec2-cluster"
  public_key = tls_private_key.ec2-k8s-key.public_key_openssh
}

# Saving private key file locally
resource "local_file" "ec2-k8s-key" {
  content  = tls_private_key.ec2-k8s-key.private_key_pem
  filename = "${local.work_path}/../inventory/k8s-ec2-cluster.pem"
  file_permission = "0400"
}

# Defininng the instances
resource "aws_instance" "k8s" {
  for_each               = toset(var.instance_tag)
  ami                    = var.ami_id
  instance_type          = var.instance_flavour
  key_name               = aws_key_pair.tf-k8s.key_name
  subnet_id              = var.subnet_name
  vpc_security_group_ids = [aws_security_group.allow_all.id]

  tags = {
    Name = "k8s-${each.key}"
  }
}

locals {
  work_path = path.module
  public_ips = [for k, v in aws_instance.k8s : v.public_ip]
  ec2_master = [local.public_ips[0]]
  ec2_slaves = [for index, ip in local.public_ips : ip if index > 0]
}

# OUtput master ip
output "ec2_master" {
  value = local.ec2_master
}

# Output slave ips
output "ec2_slaves" {
  value = local.ec2_slaves
}

# Create inventory file to be used by Ansible
resource "local_file" "ansible_inventory" {
  content  = <<EOF
[ec2_master]
${join("\n", local.ec2_master)}
[ec2_slave]
${join("\n", local.ec2_slaves)}
EOF
  filename = "${local.work_path}/../inventory/cluster-inventory.yaml"
}

# Checking if master host is up and calling ansible for config-management
resource "null_resource" "ansible" {
    provisioner "remote-exec" {
      inline = ["echo 'Waiting for server to be initialized...'"]

      connection {
        type        = "ssh"
        host        = local.ec2_master[0]
        user        = "ec2-user"
        private_key = tls_private_key.ec2-k8s-key.private_key_pem
      }
  }

  provisioner "local-exec" {
    working_dir = "${local.work_path}/../ansible/"
    command = "ansible-playbook -i ../inventory/cluster-inventory.yaml setup.yml"
  }
  depends_on = [
    aws_instance.k8s,
    local_file.ansible_inventory,
  ]
}
