# Define the provider
provider "aws" {
  region = var.region_name
}

# Define security group
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

# Create a private/pub key
resource "tls_private_key" "ec2-k8s-key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create the EC2 key pair
resource "aws_key_pair" "tf-k8s" {
  key_name   = "tf-k8s"
  public_key = tls_private_key.ec2-k8s-key.public_key_openssh
}

# Save private key file locally
resource "local_file" "ec2-k8s-key" {
  content  = tls_private_key.ec2-k8s-key.private_key_pem
  filename = "ec2-k8s-key.pem"
}

# Define the instances
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
  filename = "cluster-inventory.yaml"
}

# # Generate inventory file for Ansible
# locals {
#   ec2_master = tolist([aws_instance.k8s.0.private_ip])
#   ec2_slave = tolist(aws_instance.k8s[1:].*.private_ip)
#   inventory_content = templatefile("inventory.tpl", {ec2_master = local.ec2_master, ec2_slave = local.ec2_slave})
# }

# resource "local_file" "inventory_file" {
#   content  = local.inventory_content
#   filename = "inventory"
# }

# # Define Ansible inventory template
# data "template_file" "inventory_template" {
#   template = "${file("inventory.tpl")}"
#   vars = {
#     ec2_master = local.ec2_master
#     ec2_slave = local.ec2_slave
#   }
# }

##################

