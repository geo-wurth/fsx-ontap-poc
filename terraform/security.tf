resource "aws_security_group" "clients" {
  name        = "fsx-ontap-poc-clients"
  description = "Security group for Linux and Windows clients"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-clients-sg"
  }
}

resource "aws_security_group" "fsx" {
  name        = "fsx-ontap-poc-fsx"
  description = "Security group for FSx ONTAP"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-fsx-sg"
  }
}

# FSx Inbound Rules
# Allow ICMP
resource "aws_security_group_rule" "fsx_ingress_icmp" {
  type                     = "ingress"
  from_port                = -1
  to_port                  = -1
  protocol                 = "icmp"
  security_group_id        = aws_security_group.fsx.id
  source_security_group_id = aws_security_group.clients.id
  description              = "Allow ICMP from clients"
}

# Allow NFS (TCP 111, 635, 2049)
resource "aws_security_group_rule" "fsx_ingress_nfs_111" {
  type                     = "ingress"
  from_port                = 111
  to_port                  = 111
  protocol                 = "tcp"
  security_group_id        = aws_security_group.fsx.id
  source_security_group_id = aws_security_group.clients.id
  description              = "Allow NFS portmapper from clients"
}

resource "aws_security_group_rule" "fsx_ingress_nfs_635" {
  type                     = "ingress"
  from_port                = 635
  to_port                  = 635
  protocol                 = "tcp"
  security_group_id        = aws_security_group.fsx.id
  source_security_group_id = aws_security_group.clients.id
  description              = "Allow NFS mountd from clients"
}

resource "aws_security_group_rule" "fsx_ingress_nfs_2049" {
  type                     = "ingress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  security_group_id        = aws_security_group.fsx.id
  source_security_group_id = aws_security_group.clients.id
  description              = "Allow NFS from clients"
}

# Allow SMB (TCP 135, 139, 445)
resource "aws_security_group_rule" "fsx_ingress_smb_135" {
  type                     = "ingress"
  from_port                = 135
  to_port                  = 135
  protocol                 = "tcp"
  security_group_id        = aws_security_group.fsx.id
  source_security_group_id = aws_security_group.clients.id
  description              = "Allow RPC from clients"
}

resource "aws_security_group_rule" "fsx_ingress_smb_139" {
  type                     = "ingress"
  from_port                = 139
  to_port                  = 139
  protocol                 = "tcp"
  security_group_id        = aws_security_group.fsx.id
  source_security_group_id = aws_security_group.clients.id
  description              = "Allow NetBIOS from clients"
}

resource "aws_security_group_rule" "fsx_ingress_smb_445" {
  type                     = "ingress"
  from_port                = 445
  to_port                  = 445
  protocol                 = "tcp"
  security_group_id        = aws_security_group.fsx.id
  source_security_group_id = aws_security_group.clients.id
  description              = "Allow SMB from clients"
}

# Allow ONTAP Management (TCP 22, 443)
resource "aws_security_group_rule" "fsx_ingress_mgmt_22" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  security_group_id        = aws_security_group.fsx.id
  source_security_group_id = aws_security_group.clients.id
  description              = "Allow SSH management from clients"
}

resource "aws_security_group_rule" "fsx_ingress_mgmt_443" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.fsx.id
  source_security_group_id = aws_security_group.clients.id
  description              = "Allow HTTPS management from clients"
}

resource "aws_security_group_rule" "fsx_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.fsx.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound traffic from FSx"
}
