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


### VPC

terraformでVPCやサブネットを構築するにあたり、インフラについては久々に触るので概要を整理する。  
VPCは<span style="color: #338833;">10.0.0.0/16</span>のような値を指定する。これは<span style="color: #338833;">[IPアドレス]/[プレフィックス長]</span>の構成となっている。  
最初の16ビットがネットワーク部で、残りの16ビットがホスト部。  
この10は、IPアドレスの最初のオクテット(8ビット)を表している。  
各オクテットは 0 から 255 の値を取ります（8ビットで表現できる最大値が 255）。

ビット（bit）：コンピュータが扱う最小の情報単位。0 か 1 の値を取ります。  
バイト（byte）：8ビットで構成される情報の単位。
だから00001010は8ビットで構成されていて、これで1バイトと表現する。  
なので<span style="color: #338833;">10.0.0.0/16</span>の10(10進数)はバイトに戻すると00001010 = 2 + 8で10となる。

#### IPアドレスのネットワーク部とホスト部について


ネットワーク部：  
IPアドレスの先頭から、CIDRのプレフィックス長で指定されたビット数まで。  
同じネットワーク内のすべてのデバイスで共通。  
ネットワークを識別するために使用。  

ホスト部：  
ネットワーク部の後の残りのビット。  
同じネットワーク内の個々のデバイスを識別。  
ネットワーク内で一意である必要がある。  

例（10.0.0.0/16の場合）：
10.0.   |   0.0
ネットワーク部 | ホスト部

#### IPアドレスの種類

さらにIPアドレスは2種類存在する。  
パブリックIPアドレス：インターネット上で一意、直接インターネットに接続可能  
プライベートIPアドレス：ローカルネットワーク内で使用、異なるネットワーク間で重複可能  

さらにプライベートIPアドレスにはあらかじめ予約された範囲が存在し、一般的にはこちらを指定する。 
クラスA プライベートアドレス:  
範囲: 10.0.0.0 - 10.255.255.255  
CIDR表記: 10.0.0.0/8  
利用可能アドレス数: 約1670万個  

クラスB プライベートアドレス:  
範囲: 172.16.0.0 - 172.31.255.255  
CIDR表記: 172.16.0.0/12  
利用可能アドレス数: 約104万個  

クラスC プライベートアドレス:  
範囲: 192.168.0.0 - 192.168.255.255  
CIDR表記: 192.168.0.0/16  
利用可能アドレス数: 約6.5万個  

これらはプライベートIPアドレスとして確約されており、将来的にパブリックIPアドレスとして割り当てられる可能性がない。  

例えば、10.0.0.0/16というプライベートIPアドレスをVPCに割り当てると、  
サブネットを、下記のように分類できて、  
10.1.0.0/16
10.2.0.0/16

EC2やlambdaを10.1.0.1/16、10.1.0.2/16のように割り当てることができる。

#### NATについて
プライベートIPアドレスが外部のインターネットに接続できる仕組みとして、NATがある。  
NAT（Network Address Translation）：  
ルーターで行われる  
内部のプライベートIPアドレスを外部のパブリックIPアドレスに変換  
これにより、プライベートネットワーク内の複数デバイスが1つのパブリックIPを共有してインターネットにアクセス可能  


#### DHCPについて

さらにプライベートIPアドレスの割り当ての仕組みとしては、DHCPがある。  
DHCPサーバー：  
多くの場合、ルーターに内蔵されている  
ネットワーク内のデバイスにプライベートIPアドレスを動的に割り当てる  
同じネットワーク内でのIPアドレスの重複を防ぐ  

#### サブネットがどのようにして、各サービスにアクセスするか？

ルートテーブルという仕組みで実現する。  
ルートテーブルの基本：  
- VPC内のネットワークトラフィックの経路を定義します。
- 各サブネットは1つのルートテーブルに関連付けられます。
- 1つのルートテーブルを複数のサブネットで共有することも可能です。
- 同じVPC内のサブネット間通信はデフォルトで許可されています。

### IAMについて

IAMもAWSサービスを構築するにあたり重要な概念である。
調査した結果と理解を下記にまとめる。

#### IAMロール

ロールは「誰が」or「何が」ポリシー(権限)を持つかを定義する。  
主な用途としては下記
- AWS サービス用のロール
    - Lambda 関数用のロール
        ```
        // ロール
        resource "aws_iam_role" "lambda_role" {
            name = "lambda-s3-role"
            assume_role_policy = jsonencode({
                Version = "2012-10-17"
                Statement = [
                    {
                        Action = "sts:AssumeRole"
                        Effect = "Allow"
                        Principal = { // これが信頼ポリシーで、lambdaがこのロールを受けられることを意味する。
                            Service = "lambda.amazonaws.com"
                        }
                    }
                ]
            })
        }

        // 上記のロールをlambdaに関連付ける。
        resource "aws_lambda_function" "example" {
            filename      = "lambda_function.zip"
            function_name = "example_lambda"
            role          = aws_iam_role.lambda_role.arn // ここでarnを指定して関連付け
            handler       = "index.handler"
            runtime       = "nodejs14.x"
        }
        ```
    - EC2 インスタンス用のロール
- クロスアカウントアクセス用のロール
    - 別の AWS アカウントのユーザーがこのロールを引き受けてリソースにアクセス
- フェデレーションユーザー用のロール
    - 外部の ID プロバイダ（例：Active Directory）を使用するユーザー用
- アプリケーション用のロール
    - モバイルアプリなどが一時的に AWS リソースにアクセスする際に使用

#### IAMポリシー

ロールの構成要素としてポリシーという概念がある。  
- 信頼ポリシー（Trust Policy）
    - どのエンティティがこのロールを引き受けられるかを定義
- 権限ポリシー（Permission Policy）
    - ロールが持つ実際の権限を定義。何ができるかを指定する。  
        ```
        {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow", // 許可、拒否 
                    "Action": ["s3:GetObject", "s3:PutObject"], // どんな動作を
                    "Resource": "arn:aws:s3:::example-bucket/*" // 何に適用するか
                }
            ]
        }
        ```  
    
     - さらに権限ポリシーにはタイプが３つ存在する。
        - AWS管理ポリシー: AWSが事前定義し、管理するポリシー
            ```
            resource "aws_iam_role_policy_attachment" "s3_read_only" {
                policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
                role       = aws_iam_role.example_role.name
            }
            ```
        - カスタマー管理ポリシー: - ユーザーが作成し管理するポリシー。複数のエンティティで再利用可能
            ```
            resource "aws_iam_policy" "s3_read_write" {
                name        = "s3_read_write_policy"
                path        = "/"
                description = "Allow read and write access to specific S3 bucket"

                policy = jsonencode({
                    Version = "2012-10-17"
                    Statement = [
                        {
                            Effect = "Allow"
                            Action = [
                                "s3:GetObject",
                                "s3:PutObject"
                            ]
                            Resource = "arn:aws:s3:::example-bucket/*"
                        }
                    ]
                })
            }

            resource "aws_iam_role_policy_attachment" "s3_access" {
                policy_arn = aws_iam_policy.s3_read_write.arn
                role       = aws_iam_role.example_role.name
            }
            ```
        - インラインポリシー: 特定のユーザー、グループ、ロールに直接埋め込まれたポリシー
            ```
            resource "aws_iam_role_policy" "lambda_s3_policy" {
                name = "lambda-s3-policy"
                role = aws_iam_role.lambda_role.id

                policy = jsonencode({
                    Version = "2012-10-17"
                    Statement = [
                        {
                            Effect = "Allow"
                            Action = [
                                "s3:GetObject",
                                "s3:PutObject"
                            ]
                            Resource = "arn:aws:s3:::example-bucket/*"
                        }
                    ]
                })
            }
            ```
ポリシーのテストをすることも可能で、ポリシーシミュレータツールが存在する。  
複数のポリシーが適用される場合、権限は累積的

Effectの権限評価ロジックは、
- 明示的な Deny > 明示的な Allow > 暗黙的な Deny  
明示的に許可（Allow）されていない限り、すべてのアクションは拒否されます。
- 1つでも明示的な Deny があれば、アクションは拒否される

ポリシー適用の流れとしては、
- 必要な権限を持つポリシーを作成し、IAMエンティティ（ユーザー、グループ、ロール）に適用します。  
ポリシーは前述のロール以外にもユーザーやグループにも適用することができる。
- 基本的には、必要な権限を「Allow」するポリシーを適用していきます。
- 可能な限りAWS管理ポリシーを使用し、必要に応じてカスタマー管理ポリシーで補完します。  
インラインポリシーは、本当に特定のエンティティにのみ適用される権限の場合にのみ使用します。


#### リソースベースのポリシー

先述のIAMポリシーと似ているが異なる概念として、「リソースベースのポリシー」がある。  
下記のように、直接リソース(opensearch等)に定義し、アクセスできるエンティティ(lambda等)を指定する。  
Principalが存在するので、信頼ポリシー（どのエンティティがロールの引き受けるか許可するか）と混同しそうだが、  
信頼ポリシーはロールに記述するのに対して、リソースベースのポリシーは直接リソースに定義する点が異なる。  
またリソースに直接定義しているので、インラインポリシーとも混同しそうだが、リソースベースのポリシーはどのリソースから何を許可するかを設定する。
インラインポリシーはリソースが何ができるかを指定する。
```
resource "aws_opensearch_domain" "domain" {
    省略...

  access_policies = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = var.lambda_role_arn // 指定された Lambda ロールにアクセスを許可します。
        }
        Action = "es:*" // すべての OpenSearch アクションを許可します。
        Resource = "arn:aws:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/${var.opensearch_domain_name}/*"
        // 特定の OpenSearch ドメインへのアクセスを制限します。
      }
    ]
  })
```

#### セキュリティグループ

ファイアウォールとほぼ同義でネットワーク通信関連を制御する。  
IAM、リソースベース、セキュリティグループの層についての目的を理解する。  

1. IAMレベルのセキュリティ（Who are you? What are you allowed to do?）:  
   - Lambdaのロール作成（信頼ポリシー）
      - 目的：Lambdaサービスにロールの引き受けを許可  
   - Lambdaにロールを適用  
   - OpenSearchアクセス用のポリシー作成  
   - ポリシーをLambdaロールに適用  
      - 目的：LambdaにOpenSearchへのアクセス権限を付与

2. リソースレベルのセキュリティ（Who can access me?）:  
   - OpenSearchにリソースベースのポリシーを定義
      - 目的：OpenSearch側でLambdaからのアクセスを許可

3. ネットワークレベルのセキュリティ（How can you reach me?）:  
   - セキュリティグループの設定
      - Lambda用セキュリティグループ：アウトバウンドトラフィックの制御
      - OpenSearch用セキュリティグループ：インバウンドトラフィックの制御
      - 目的：ネットワークレベルでの通信制御

補足ポイント：  
1. 多層防御：
   - IAM、リソースポリシー、ネットワークセキュリティの各層で制御することで、より堅牢なセキュリティを実現します。

2. 最小権限の原則：
   - 各層で必要最小限の権限のみを付与することが重要です。

3. ネットワークセキュリティの重要性：
   - セキュリティグループはファイアウォールのような役割を果たし、不要な通信を物理的にブロックします。

4. 相互補完的な設定：
   - IAMポリシーで許可されていても、セキュリティグループでブロックされていれば通信は行えません。逆も同様です。

5. 柔軟性と管理：
   - IAMとリソースポリシーは細かい制御が可能ですが、セキュリティグループはより大まかな制御に適しています。
   - セキュリティグループの変更は即時反映されるため、緊急時の対応に有用です。

6. 監査とコンプライアンス：
   - 各層での設定を適切に行うことで、セキュリティ監査やコンプライアンス要件への対応が容易になります。

この包括的なアプローチにより、アプリケーションレベル（IAM）、サービスレベル（リソースポリシー）、ネットワークレベル（セキュリティグループ）でのセキュリティを確保し、堅牢で安全なAWS環境を構築することができます。

#### lambdaからopensearchにアクセスするためのさっくりした流れ。

前提条件:
- lambdaとopensearchは同じVPC内にいる
- lambdaとopensearchはそれぞれ別のプライベートサブネットに存在する。

流れ
- ロールを作成する。（lambdaに割り当てできるようにする。信頼ポリシー。）  
- lambdaにロールを適用する。  
- lambdaがopensearchにアクセスできるような、ポリシーを作成する。  
- そのポリシーをlambdaに適用する。これはカスタマー管理ポリシーで定義（AWS管理ポリシーがあるのならそれを使う。）  
- これだけだとopensearch側でlambdaのアクセスを受け入れる権限がないので、opensearch側にリソースベースのポリシーを定義して、lambdaの動作を許可する。  
- セキュリティグループをlambdaとopensearchに適用して、ネットワーク通信の許可をする。




TODO: 
- 現在の構成を図にしたい、特にVPC周りの関係性についてキャッチアップする。
- lambdaの中身を実装したい
- opensearchの仕様を把握する。
- S3にはlambdaからのアクセスを許可する、リソースベースのポリシーが必要ないのはなぜ？
