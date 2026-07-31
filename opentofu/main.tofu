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