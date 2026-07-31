resource "tls_private_key" "kthw_key" {
  algorithm = "ED25519"
}

resource "aws_key_pair" "kthw_key" {
  key_name   = "kthw_key"
  public_key = tls_private_key.kthw_key.public_key_openssh
}

resource "local_sensitive_file" "private_key" {
  content         = tls_private_key.kthw_key.private_key_pem
  filename        = "${path.module}/.ssh/kthw_key.pem"
  file_permission = "0600"
}

resource "aws_default_vpc" "default" {
  tags = {
    Name = "kthw_vpc"
  }
}

resource "aws_default_security_group" "default" {
  vpc_id = aws_default_vpc.default.id
  tags = {
    Name = "kthw_sg"
  }
  
  ingress {
    description = "SSH - open to internet, for lab only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol  = -1
    self      = true
    from_port = 0
    to_port   = 0
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}