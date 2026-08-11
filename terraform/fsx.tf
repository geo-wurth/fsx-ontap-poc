resource "aws_fsx_ontap_file_system" "fsx" {
  storage_capacity    = var.fsx_storage_capacity
  subnet_ids          = [aws_subnet.private.id]
  deployment_type     = "SINGLE_AZ_1"
  throughput_capacity = var.fsx_throughput
  preferred_subnet_id = aws_subnet.private.id
  fsx_admin_password  = var.fsx_admin_password
  
  security_group_ids = [aws_security_group.fsx.id]

  # Configuração para POC
  automatic_backup_retention_days = 0 # Desabilita backup automático
  skip_final_backup               = true # Evita snapshot no destroy

  tags = {
    Name = "${var.project_name}-fs"
  }
}

resource "aws_fsx_ontap_storage_virtual_machine" "svm" {
  file_system_id = aws_fsx_ontap_file_system.fsx.id
  name           = "svmpoc"
  svm_admin_password = var.fsx_admin_password

  root_volume_security_style = "UNIX"

  tags = {
    Name = "${var.project_name}-svm"
  }
}

resource "aws_fsx_ontap_volume" "nfs_volume" {
  name                       = "vol_nfs"
  junction_path              = "/vol_nfs"
  size_in_megabytes          = var.nfs_volume_size * 1024
  storage_efficiency_enabled = true
  storage_virtual_machine_id = aws_fsx_ontap_storage_virtual_machine.svm.id
  security_style             = "UNIX"

  skip_final_backup = true

  tags = {
    Name = "${var.project_name}-vol-nfs"
  }
}

resource "aws_fsx_ontap_volume" "smb_volume" {
  name                       = "vol_smb"
  junction_path              = "/vol_smb"
  size_in_megabytes          = var.smb_volume_size * 1024
  storage_efficiency_enabled = true
  storage_virtual_machine_id = aws_fsx_ontap_storage_virtual_machine.svm.id
  security_style             = "NTFS"

  skip_final_backup = true

  tags = {
    Name = "${var.project_name}-vol-smb"
  }
}
