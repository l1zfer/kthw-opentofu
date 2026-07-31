variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "subnet_az1" {
  type    = string
  default = "eu-central-1a"
}

variable "ami" {
  type    = string
  default = "ami-061c3cc439c70beea"
}

variable "jumpbox_instance_type" {
  type    = string
  default = "t2.nano"
}

variable "k8s_instance_type" {
  type    = string
  default = "t2.small"
}