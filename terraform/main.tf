// リファクタ対象: ほぼ全てvarで定義しているが、決まりきった値は直接記述したほうが可読性が良くなるかも。

// dataは外部のリソースを読み取る。doppler_secretsはDopplerからシークレットを取得する。thisは任意の名前。
// 取得したいプロジェクトと環境を指定する。
data "doppler_secrets" "this" {
  project = "original_bot"
  config  = "dev"
}

// moduleは関数の概念に近い、この定義を./modules/s3に適応している。
module "s3_bucket" {
  source      = "./modules/s3"
  bucket_name = var.opensearch_document_bucket_name // ここの親の定義は、./modules/s3/main.tfに引き継がれオーバライドされる。そしてここに設定する値は/modules/s3/variables.tfに変数として定義しておかないとエラーになる。
  tags        = var.common_tags

  // S3はグローバルサービスなのでVPCの設定は不要。
}

module "lambda_function" {
  source             = "./modules/lambda"
  function_name      = "document_processor"
  lambda_source_file = "${path.module}/../src/lambda/document_processor/dist/index.js" // memo: 現状1つしかlambdaがないが、今後は増える可能性がある。
  s3_bucket_arn      = module.s3_bucket.bucket_arn
  vpc_config = {
    subnet_ids         = module.vpc.private_subnet_ids
    security_group_ids = [module.vpc.lambda_security_group_id]
  }
  tags               = var.common_tags

  opensearch_endpoint   = module.opensearch_domain.endpoint
  opensearch_username   = data.doppler_secrets.this.map.OPENSEARCH_USERNAME
  opensearch_password   = data.doppler_secrets.this.map.OPENSEARCH_PASSWORD
  opensearch_domain_arn = module.opensearch_domain.arn
}

module "opensearch_domain" {
  source                    = "./modules/opensearch"
  opensearch_domain_name    = var.opensearch_domain_name
  opensearch_engine_version = var.opensearch_engine_version
  instance_type             = var.opensearch_instance_type
  instance_count            = var.opensearch_instance_count
  zone_awareness_enabled    = true
  availability_zone_count   = 2
  vpc_options = {
    subnet_ids         = module.vpc.private_subnet_ids
    security_group_ids = [module.vpc.opensearch_security_group_id]
  }
  tags                      = var.common_tags
  opensearch_username = data.doppler_secrets.this.map.OPENSEARCH_USERNAME
  opensearch_password = data.doppler_secrets.this.map.OPENSEARCH_PASSWORD
  lambda_role_arn     = module.lambda_function.role_arn
}

// resourceは、実際にAWSのリソースを作成する定義。
// S3にオブジェクトが作成されたときにLambda関数をトリガーする
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = module.s3_bucket.bucket_id

  lambda_function {
    lambda_function_arn = module.lambda_function.function_arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [module.lambda_function]
}

# API Gateway
resource "aws_api_gateway_rest_api" "document_processor" {
  name        = "document-processor-api"
  description = "API for document processing"
}

# VPC
module "vpc" {
  source = "./modules/vpc"
  common_tags = var.common_tags
}
