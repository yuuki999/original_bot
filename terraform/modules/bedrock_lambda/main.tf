data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = var.lambda_source_file
  source_dir  = "${path.module}/../../../src/lambda/bedrock_processor/dist"
  output_path = "${path.module}/../../../src/lambda/bedrock_processor/function.zip"
}

resource "aws_lambda_function" "bedrock_lambda" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = var.function_name
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "nodejs20.x"

  vpc_config {
    subnet_ids         = var.vpc_config.subnet_ids
    security_group_ids = var.vpc_config.security_group_ids
  }

  environment {
    variables = {
      BEDROCK_ENDPOINT     = var.bedrock_endpoint
      OPENSEARCH_ENDPOINT  = var.opensearch_endpoint
      OPENSEARCH_USERNAME  = var.opensearch_username
      OPENSEARCH_PASSWORD  = var.opensearch_password
      BEDROCK_MODEL_ID     = var.bedrock_model_id
      OPENSEARCH_INDEX     = var.opensearch_index
      BEDROCK_MAX_TOKENS   = var.bedrock_max_tokens
    }
  }

  tags = var.tags
}

# Lambda関数のIAMロール
resource "aws_iam_role" "lambda_role" {
  name = "${var.function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Lambda基本実行ポリシーのアタッチ
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_role.name
}

# Lambda VPCアクセスポリシーのアタッチ
resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  role       = aws_iam_role.lambda_role.name
}

# Bedrock使用のためのIAMポリシー
resource "aws_iam_role_policy" "bedrock_access" {
  name = "${var.function_name}-bedrock-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = "*"
      }
    ]
  })
}

# OpenSearch接続用のIAMポリシー
resource "aws_iam_role_policy" "opensearch_access" {
  name = "${var.function_name}-opensearch-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "es:ESHttpGet",
          "es:ESHttpPost",
          "es:ESHttpPut"
        ]
        Resource = "${var.opensearch_domain_arn}/*"
      }
    ]
  })
}
