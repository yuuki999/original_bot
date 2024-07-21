### terraformコマンド

初期化
- Terraformモジュールのダウンロードとインストール
- バックエンドの設定と初期化（状態ファイルの保存場所）
- プロバイダのプラグインのダウンロードとインストール

reconfigureオプション
- 現在のバックエンド設定を無視して、backend セクションの設定を再度読み込みます。
- 既存の設定を変更する場合や、新しいバックエンドに切り替える場合に使用します。

デプロイ手順
```
./scripts/build_lambdas.sh # lambda関数を更新した場合
terraform init
terraform init -upgrade # required_providersのバージョンを変えて依存関係を更新したい場合
terraform plan # 設定、エラー確認
terraform apply # デプロイ
terraform show # 構成の確認
terraform plan -destroy # 削除プランの確認
terraform destroy　#　削除
```


### awsコマンド

バケット作成
```
aws s3api create-bucket --bucket terraform-state-bucket-yuuki-$(date +%s) --region us-east-1 --profile dev
```
バケット存在確認
```
aws s3 ls s3://terraform-state-bucket-yuuki-172106066 --profile dev
aws s3api get-bucket-location --bucket terraform-state-bucket-yuuki-172106066 --profile dev
```
バケットのバージョニング確認
```
aws s3api get-bucket-versioning --bucket terraform-state-bucket-yuuki-172106066 --profile dev
```
バケットのバージョニングを有効にする
```
aws s3api put-bucket-versioning --bucket terraform-state-bucket-yuuki-172106066 --versioning-configuration Status=Enabled --profile dev
```

指定したS3にファイルをアップロードする。
```
echo "Hello, this is a test file" > test.txt
aws s3 cp test.txt s3://document-processor-bucket-yuuki/test.txt --profile dev
```

CWからログを確認する。
```
aws logs get-log-events --log-group-name /aws/lambda/document_processor --log-stream-name $(aws logs describe-log-streams --log-group-name /aws/lambda/document_processor --query 'logStreams[0].logStreamName' --output text) --profile dev #権限エラーになる。対応はしているので時間が経てばうまくいくかも？
```

### 環境変数はDopplerで管理

Dopplerのアカウントを作り、CLIインストール
```
brew install dopplerhq/cli/doppler
```

ログインする。
```
cd ./terraform
doppler login
```

ログイン成功確認
```
doppler whoami
```

プロジェクト作成（今回は省略）
```
doppler projects create original_bot
```

doppler projects
```
プロジェクト一覧を確認
```

プロジェクトと環境を選択する。
```
➜  original_bot git:(main) ✗ doppler setup
? Select a project: original_bot
? Select a config: dev
```


環境変数一覧を確認
```
doppler secrets
doppler secrets --config dev
doppler secrets --project original_bot --config dev
```

環境変数をセットする。
```
doppler secrets set HOGE_KEY hoge_value
```

dopplerトークンを確認する方法
```
doppler configure --json | grep -o '"token":"[^"]*' | sed 's/"token":"//'
```

ローカルの環境変数を設定
```
export DOPPLER_TOKEN=$(doppler configure --json | grep -o '"token":"[^"]*' | sed 's/"token":"//')
```
設定したローカルの環境変数を、terraform/terraform.tfvarsの変数にセットする。
```
export TF_VAR_doppler_token=$DOPPLER_TOKEN
```


TODO: 
- 現在の構成を図にしたい、特にVPC周りの関係性についてキャッチアップする。
- lambdaの中身を実装したい
- opensearchの仕様を把握する。
