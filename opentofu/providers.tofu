terraform {
  required_providers {
    aws = {
      source  = "opentofu/aws"
      version = "6.57.1"
    }
  }
}

provider "aws" {
  region = var.region
}