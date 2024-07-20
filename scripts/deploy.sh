#!/bin/bash

# Lambdaのビルド
./scripts/build_lambdas.sh

# Terraformのデプロイ（環境に応じて）
cd terraform/environments/dev  # または prod
terraform init
terraform apply
