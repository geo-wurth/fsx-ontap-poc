data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

data "aws_ami" "windows_2022" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }
}

resource "aws_instance" "linux" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = var.linux_instance_type
  subnet_id     = aws_subnet.public.id
  
  vpc_security_group_ids = [aws_security_group.clients.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y nfs-utils cifs-utils fio sysstat
              EOF

  tags = {
    Name = "${var.project_name}-linux"
  }
}

resource "aws_instance" "windows" {
  ami           = data.aws_ami.windows_2022.id
  instance_type = var.windows_instance_type
  subnet_id     = aws_subnet.public.id

  vpc_security_group_ids = [aws_security_group.clients.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name

  tags = {
    Name = "${var.project_name}-windows"
  }
}
