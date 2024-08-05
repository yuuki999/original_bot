# VPCの設定
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.common_tags, {
    Name = "document-processor-vpc"
  })
}

data "aws_availability_zones" "available" {
  state = "available"
}

# サブネットの設定
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 1}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(var.common_tags, {
    Name = "document-processor-private-subnet-${count.index + 1}"
  })
}

# lambdaセキュリティグループの設定
resource "aws_security_group" "lambda" {
  name        = "document-processor-lambda-sg"
  description = "Security group for Lambda function"
  vpc_id      = aws_vpc.main.id

  // 全てのアウトバウンドトラフィックを許可 
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.common_tags
}

// 踏み台サーバー（バスティオンホスト）のセキュリティグループ
resource "aws_security_group" "bastion_sg" {
  name        = "bastion-security-group"
  description = "Security group for bastion host"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.bation_ip}/0"] // 自分のIPアドレス
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# opensearchセキュリティグループの設定
resource "aws_security_group" "opensearch" {
  name        = "document-processor-opensearch-sg"
  description = "Security group for OpenSearch domain"
  vpc_id      = aws_vpc.main.id

  // Lambdaのセキュリティグループ（aws_security_group.lambda.id）からのインバウンドトラフィックを443ポート（HTTPS）で許可。
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]
  }

  // ダッシュボードにアクセスするために、許可するIPアドレスを指定
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.100.0.0/16"]  // クライアントVPNのCIDR
  }

  // 踏み台サーバー（バスティオンホスト）からのアクセスを許可
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]  // 踏み台サーバーのセキュリティグループID
  }

  tags = var.common_tags
}

# プライベートルートテーブルの作成
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.common_tags, {
    Name = "document-processor-private-route-table"
  })
}

# サブネットをルートテーブルに関連付け
resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

data "aws_region" "current" {}

# S3用のVPCエンドポイントを作成
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = [aws_route_table.private.id]

  tags = merge(var.common_tags, {
    Name = "document-processor-s3-endpoint"
  })
}

# インターネットゲートウェイの作成
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

# パブリックルートテーブルの作成（または既存のものを更新）
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "Public Route Table"
  }
}

# パブリックサブネットの設定
resource "aws_subnet" "public" {
  count             = 1
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 101}.0/24"  # プライベートサブネットと重複しないCIDRを使用
  availability_zone = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true  # このサブネットで起動されるインスタンスにパブリックIPを自動割り当て

  tags = merge(var.common_tags, {
    Name = "document-processor-public-subnet-${count.index + 1}"
  })
}

# パブリックサブネットとルートテーブルの関連付け
resource "aws_route_table_association" "public" {
  count          = 1 
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
