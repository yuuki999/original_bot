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
