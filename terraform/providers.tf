terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    doppler = {
      source  = "DopplerHQ/doppler"
      version = "~> 1.2.0"
    }
    // 証明書の作成に必要なTLSプロバイダー
    tls = {
      source  = "hashicorp/tls"
      version = "~> 3.0"
    }
  }

  // terraformのstateファイルをS3に保存する設定、何もしないとローカルに保存される。
  backend "s3" {
    bucket = "terraform-state-bucket-yuki"
    key    = "dev/terraform.tfstate"
    region = "us-east-2"
    # profile = "dev"
  }
}

provider "doppler" {
  doppler_token = var.doppler_token
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}
