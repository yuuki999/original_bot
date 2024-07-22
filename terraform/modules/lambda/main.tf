// lambda関数をzipとして保存。このzipファイルをlambda関数としてデプロイする。
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../../src/lambda/document_processor/dist" // typescriptで書かれたlambda関数のビルド後のディレクトリ
  output_path = "${path.module}/../../../src/lambda/document_processor/function.zip" // これはterraform planの段階で生成される
}

// lmabda関数の定義元。
resource "aws_lambda_function" "document_processor" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = var.function_name
  role             = aws_iam_role.lambda_role.arn // lambdaのロールを関連づけ。
  handler          = var.handler
  runtime          = var.runtime // 実行環境を定義。node等
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  // lambda関数がアクセスする環境変数の定義。
  environment {
    variables = {
      OPENSEARCH_ENDPOINT = var.opensearch_endpoint
      LAMBDA_ROLE_ARN     = aws_iam_role.lambda_role.arn
      # OPENSEARCH_USERNAME = var.opensearch_username
      # OPENSEARCH_PASSWORD = var.opensearch_password
    }
  }

  // lambdaとopensearchを同じVPCにして、VPCエンドポイントを使って通信する。
  vpc_config {
    subnet_ids         = var.vpc_config.subnet_ids
    security_group_ids = var.vpc_config.security_group_ids
  }

  tags = var.tags
  timeout = 180 // lambdaのタイムアウトを180秒に設定。最大15分まで伸ばせる。https://docs.aws.amazon.com/ja_jp/lambda/latest/dg/configuration-timeout.html
  memory_size = 512 // lambdaのメモリサイズを増やす。デフォルトは128MB。最大は10240MB(10GB) https://docs.aws.amazon.com/ja_jp/lambda/latest/dg/gettingstarted-limits.html
}

// lambda関数が他のAWSリソースにアクセスするためのIAMロールの定義。
// ロールは「誰が」or「何が」ポリシーを持つかを定義する。
resource "aws_iam_role" "lambda_role" {
  name = "${var.function_name}-role"

  // 信頼ポリシーの定義。lambda関数がこのロールをアサインすることを許可する。逆に特定のサービスがこのロールへのアクセスを拒否することも可能。
  assume_role_policy = jsonencode({
    Version = "2012-10-17" // このバージョンが最新
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

  // すでにポリシーが存在すれば、変更を無視する。
  lifecycle {
    ignore_changes = [assume_role_policy]
  }
}

// lambda関数IAMロールに管理ポリシーをアタッチする。
// 管理ポリシーは複数のロールにアタッチできるが、インラインポリシーは1つのロールにしかアタッチできない。
// memo: 本番環境では最小限の権限を与えるべき。
resource "aws_iam_role_policy_attachment" "lambda_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_role.name
}

// Lambda サービスのネットワークインターフェイス作成権限
resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  role       = aws_iam_role.lambda_role.name
}

// lambda関数がopensearchにアクセスするためのIAMポリシーのアタッチ、これはインラインポリシー
resource "aws_iam_role_policy" "lambda_opensearch_access" {
  name = "${var.function_name}-opensearch-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "es:ESHttpPost",
          "es:ESHttpPut",
          "es:ESHttpGet",
          "es:ESHttpHead"
        ]
        Resource = "${var.opensearch_domain_arn}/*"
      }
    ]
  })
}

// lambdaから、S3バケットにアクセスするためのIAMポリシーの定義。これはインラインポリシー
resource "aws_iam_role_policy" "lambda_s3_policy" {
  name = "${var.function_name}-s3-policy"
  role = aws_iam_role.lambda_role.id

  // 許可ポリシ-の定義。S3バケットに対してGetObjectアクションを許可する。
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${var.s3_bucket_arn}/*"
      }
    ]
  })
}

// S3がlambdaを呼び出すリソースベースのポリシー
// S3からLambdaへのトリガーの場合、S3バケット側でLambdaへのアクセスを許可するリソースベースのポリシーを指定するのではなく、
// Lambda側でS3バケットへのアクセスを許可するリソースベースのポリシーを指定する。
resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction" // lambdaの実行を許可する。
  function_name = aws_lambda_function.document_processor.arn // 権限を付与するlambdaのARN
  principal     = "s3.amazonaws.com" // S3に権限を付与する。
  source_arn    = var.s3_bucket_arn // さらに詳細にS3バケットのARN
}
