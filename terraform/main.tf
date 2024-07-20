// moduleは関数の概念に近い、この定義を./modules/s3に適応している。
module "s3_bucket" {
  source      = "./modules/s3"
  bucket_name = var.opensearch_document_bucket_name // ここの親の定義は、./modules/s3/main.tfに引き継がれオーバライドされる。
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
}

module "opensearch_domain" {
  source                    = "./modules/opensearch"
  opensearch_domain_name    = var.opensearch_domain_name
  opensearch_engine_version = var.opensearch_engine_version
  instance_type             = var.opensearch_instance_type
  instance_count            = var.opensearch_instance_count
  zone_awareness_enabled    = true
  availability_zone_count   = 2
  master_user_name          = var.opensearch_master_user_name
  master_user_password      = var.opensearch_master_user_password
  vpc_options = {
    subnet_ids         = module.vpc.private_subnet_ids
    security_group_ids = [module.vpc.opensearch_security_group_id]
  }
  tags                      = var.common_tags
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
