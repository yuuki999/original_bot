// キーペアの作成
resource "aws_key_pair" "bastion_key" {
  key_name   = "bastion-key"
  public_key = file(var.public_key_path)
}

// EC2インスタンス作成
resource "aws_instance" "bastion" {
  ami           = "ami-0430580de6244e02e"  # Amazon Linux 2 AMI ID (us-east-2)
  instance_type = "t2.micro"
  key_name      = aws_key_pair.bastion_key.key_name
  
  vpc_security_group_ids = [var.vpc_security_group_ids]
  subnet_id = var.public_subnet_id

  tags = {
    Name = "OpenSearch-Bastion"
  }
}

// Elastic IPの割り当て
resource "aws_eip" "bastion_eip" {
  instance = aws_instance.bastion.id
  vpc      = true
  
  tags = {
    Name = "OpenSearch-Bastion-EIP"
  }
}

