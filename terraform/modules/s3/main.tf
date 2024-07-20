// resource "AWSのリソース名" "任意につけることができる名前" 
// S3バケットを作成する。
resource "aws_s3_bucket" "document_bucket" {
  bucket = var.bucket_name // variables.tfで定義された変数を使用する。もしくはこのモジュールを呼び出す側（親モジュール）から値を渡すこともできるらしい。
  tags = var.tags
}

// サーバーサイド暗号化の定義
resource "aws_s3_bucket_server_side_encryption_configuration" "document_bucket_sse" {
  bucket = aws_s3_bucket.document_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

// バケットポリシー
resource "aws_s3_bucket_ownership_controls" "document_bucket_ownership" {
  bucket = aws_s3_bucket.document_bucket.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

// バケットのバージョニング設定
resource "aws_s3_bucket_versioning" "document_bucket_versioning" {
  bucket = aws_s3_bucket.document_bucket.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended" // バージョニングのオプションを調べる。
  }
}

// S3バケットにパブリックアクセスをブロックする。
resource "aws_s3_bucket_public_access_block" "document_bucket" {
  bucket = aws_s3_bucket.document_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
