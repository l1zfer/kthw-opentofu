resource "tls_private_key" "kthw_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
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

resource "aws_default_subnet" "default" {
  availability_zone = var.subnet_az1
  tags = {
    Name = "kthw_subnet"
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

resource "aws_instance" "jumpbox" {
  ami                         = var.ami
  instance_type               = var.jumpbox_instance_type
  key_name                    = aws_key_pair.kthw_key.key_name
  vpc_security_group_ids      = [aws_default_security_group.default.id]
  subnet_id                   = aws_default_subnet.default.id
  associate_public_ip_address = true
  tags = {
    Name        = "jumpbox"
    Environment = "kthw"
  }
  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail
    swapoff -a
    sed -i "/ swap / s/^\(.*\)$/#\1/g" /etc/fstab
    apt-get update -y
    apt-get install -y iptables openssl ca-certificates curl gnupg lsb-release git ansible-core
    git clone https://github.com/l1zfer/kthw-opentofu.git /root/kthw-opentofu
    ansible-galaxy collection install cloud.terraform
    cat <<EOT | tee /etc/modules-load.d/k8s.conf
    overlay
    br_netfilter
    EOT
    modprobe overlay
    modprobe br_netfilter
    cat <<EOT | tee /etc/sysctl.d/k8s.conf
    net.bridge.bridge-nf-call-iptables  = 1
    net.bridge.bridge-nf-call-ip6tables = 1
    net.ipv4.ip_forward                 = 1
    EOT
    sysctl --system
    hostnamectl set-hostname jumpbox
  EOF
  root_block_device {
    volume_size           = 10
    volume_type           = "gp3"
    delete_on_termination = true
  }
}

resource "aws_instance" "server" {
  ami                         = var.ami
  instance_type               = var.k8s_instance_type
  key_name                    = aws_key_pair.kthw_key.key_name
  vpc_security_group_ids      = [aws_default_security_group.default.id]
  subnet_id                   = aws_default_subnet.default.id
  associate_public_ip_address = true
  tags = {
    Name        = "server"
    Environment = "kthw"
  }
  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail
    swapoff -a
    sed -i "/ swap / s/^\(.*\)$/#\1/g" /etc/fstab
    apt-get update -y
    apt-get install -y iptables openssl ca-certificates curl gnupg lsb-release
    cat <<EOT | tee /etc/modules-load.d/k8s.conf
    overlay
    br_netfilter
    EOT
    modprobe overlay
    modprobe br_netfilter
    cat <<EOT | tee /etc/sysctl.d/k8s.conf
    net.bridge.bridge-nf-call-iptables  = 1
    net.bridge.bridge-nf-call-ip6tables = 1
    net.ipv4.ip_forward                 = 1
    EOT
    sysctl --system
    hostnamectl set-hostname server
  EOF
  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
  }
}

resource "aws_instance" "node" {
  count                       = 2
  ami                         = var.ami
  instance_type               = var.k8s_instance_type
  key_name                    = aws_key_pair.kthw_key.key_name
  vpc_security_group_ids      = [aws_default_security_group.default.id]
  subnet_id                   = aws_default_subnet.default.id
  associate_public_ip_address = true
  tags = {
    Name        = "node-${count.index}"
    Environment = "kthw"
  }
  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail
    swapoff -a
    sed -i "/ swap / s/^\(.*\)$/#\1/g" /etc/fstab
    apt-get update -y
    apt-get install -y iptables openssl ca-certificates curl gnupg lsb-release
    cat <<EOT | tee /etc/modules-load.d/k8s.conf
    overlay
    br_netfilter
    EOT
    modprobe overlay
    modprobe br_netfilter
    cat <<EOT | tee /etc/sysctl.d/k8s.conf
    net.bridge.bridge-nf-call-iptables  = 1
    net.bridge.bridge-nf-call-ip6tables = 1
    net.ipv4.ip_forward                 = 1
    EOT
    sysctl --system
    hostnamectl set-hostname node-${count.index}
  EOF
  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
  }
}