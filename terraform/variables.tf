variable "region_name" {
  type    = string
  default = "us-east-1"
}

variable "ami_id" {
  type    = string
  default = "ami-007868005aea67c54"
}

variable "subnet_name" {
  type    = string
  default = "subnet-0f19fd2a8c15c3839"
}

variable "instance_flavour" {
  type    = string
  default = "t2.micro"
}

variable "instance_tag" {
  type    = list(string)
  default = ["master", "slave1", "slave2"]
}

