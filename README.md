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

リソース再作成、下記コマンドでtaintしたリソースは次のapply時に強制的に再作成される。  
```
terraform taint [リソース名] # 例: terraform taint module.vpn.aws_ec2_client_vpn_authorization_rule.main
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

### opensearchのダッシュボードにアクセスする方法

1. VPCの画面から、左のサイドバー「クライアントVPNエンドポイント」をクリックする。  
https://us-east-1.console.aws.amazon.com/vpc/home?region=us-east-1#ClientVPNEndpointDetails:clientVpnEndpointId=cvpn-endpoint-08db35bf15ae55f16  
1. クライアント設定をダウンロード  
1. OpenVPNをDLする。
https://openvpn.net/client-connect-vpn-for-mac-os/
1. easy-rsaをcloneしセットアップする。
    ```
    git clone https://github.com/OpenVPN/easy-rsa.git
    cd easy-rsa/easyrsa3
    ./easyrsa init-pki // PKIの初期化
    ./easyrsa build-ca nopass // CAの作成

    ./easyrsa build-server-full server nopass // サーバー証明書の作成。Confirm request details:と出力されるので「yes」と入力
    ./easyrsa build-client-full client1.domain.tld nopass // クライアント証明書の作成。Confirm request details:と出力されるので「yes」と入力
    ```
    ファイルが生成されるので下記コマンドで、ファイルが作成されていたらOK  
    ls -la ./easyrsa3/pki/issued   
    ```
    client1.domain.tld.crt
    server.crt
    ```
    ls -la ./easyrsa3/pki/private   
    ```
    ca.key
    client1.domain.tld.key
    server.key
    ```
1. 手順2でダウンロードした<span style="color: #338833;">downloaded-client-config.ovpn</span>を編集する。
    ```
    cat ./easyrsa3/pki/issued/client1.domain.tld.crt // crtを取得
    cat ./easyrsa3/pki/private/client1.domain.tld.key // keyを取得
    ```
    <span style="color: #338833;">downloaded-client-config.ovpn</span>は下記のような内容だと思うので、 \<cert\> と \<key\> のセクションを追加します。
    ```
    client
    dev tun
    proto udp
    remote cvpn-endpoint-08db35bf15ae55f16.prod.clientvpn.us-east-1.amazonaws.com 443
    remote-random-hostname
    resolv-retry infinite
    nobind
    remote-cert-tls server
    cipher AES-256-GCM
    verb 3

    <ca>
    hoge
    </ca>

    <cert>
    -----BEGIN CERTIFICATE-----
    # client1.domain.tld.crt の内容をここにコピー
    -----END CERTIFICATE-----
    </cert>

    <key>
    -----BEGIN PRIVATE KEY-----
    # client1.domain.tld.key の内容をここにコピー
    -----END PRIVATE KEY-----
    </key>

    reneg-sec 0

    verify-x509-name clientvpn.example.com name
    ```



これは仮の手順として記録  

1. CA（認証局）の秘密鍵と公開証明書の生成
    ```
    openssl genrsa -out ca.key 2048 # CA鍵の生成 2048ビット長で作成される。
    openssl req -new -x509 -days 3650 -key ca.key -out ca.crt -subj "/CN=yuki-engineer.com" # CA証明書の生成 有効期間は10年(3650)
    ```
1. クライアント秘密鍵と公開証明書署名要求（CSR）の生成
    ```
    openssl genrsa -out client.key 2048 # クライアント鍵の生成
    openssl req -new -key client.key -out client.csr -subj "/CN=yuki-engineer.com" # クライアントCSRの生成 
    ```
1. クライアント公開証明書の作成
    ```
    openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out client.crt -days 3650
    ```
1. PKCS#12形式（.p12）のクライアント証明書の生成（オプション、WindowsのVPNクライアントで使う可能性がある。）
    ```
    openssl pkcs12 -export -clcerts -in client.crt -inkey client.key -out client.p12
    ```
1. サーバー証明書の作成
    ```
    openssl genrsa -out server.key 2048
    openssl req -new -key server.key -out server.csr -subj "/CN=yuki-engineer.com"
    openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 365 -extensions SAN -extfile <(printf "\n[SAN]\nsubjectAltName=DNS:yuki-engineer.com")
    ```
1. ここまで下記のファイルが作成されているはず。
    - ca.crt
        - CA（認証局）の証明書  
        VPNサーバーとクライアントの信頼関係を確立するために使用されます。  
        AWS ACMにアップロードする必要がある。
    - <span style="color: #338833;">ca.key</span>
        - CA（認証局）の秘密鍵  
        AWS ACMにアップロードする必要がある。  
        <span style="color: #338833;">非常に重要。安全に保管し、決して共有しないでください。</span>
    - ca.srl
        - CA（認証局）のシリアルファイル  
        証明書の発行管理に使用されます。
    - client.crt
        - クライアント証明書  
        VPNクライアントの認証に使用されます。
    - client.csr
        - クライアント証明書署名要求  
        クライアント証明書の生成プロセスで使用されました。通常は保持する必要はありません。
    - <span style="color: #338833;">client.key</span>
        - クライアント秘密鍵  
        <span style="color: #338833;">クライアント認証に使用されます。安全に保管してください。</span>
    - client.p12
        - PKCS#12形式のクライアント証明書  
        一部のVPNクライアントソフトウェアで使用されます。
    - server.crt
    - server.csr
    - server.key
1. 作成したCA証明書と秘密鍵をACMにアップロードする。
    ```
    aws acm import-certificate --certificate fileb://server.crt --private-key fileb://server.key --certificate-chain fileb://ca.crt --profile dev --region us-east-1
    ```
1. AWS VPNクライアント設定ファイルをDLする。
    ```
    aws ec2 export-client-vpn-client-configuration --client-vpn-endpoint-id cvpn-endpoint-06fbc37799e496e3c --output text  > client-config.ovpn --profile dev --region us-east-1
    ```

#### ※ CA（認証局)についての説明。

1. 定義：
   CA（Certificate Authority）は、デジタル証明書を発行し、管理する信頼できる第三者機関です。
2. 役割：
   - デジタル証明書の発行
   - 証明書の有効性の保証
   - 証明書の失効管理
3. 例え：
   CAは現実世界のパスポート発行機関のようなものです。パスポートがあなたの身元を保証するように、CAが発行したデジタル証明書はデジタル世界での身元を保証します。

パスポートのたとえを基に、デジタル証明書システムを詳しく説明します
1. CA（認証局）：
   - たとえ：政府の公印を管理する部署
   - 公開鍵（ca.crt）：公印そのもの
   - 秘密鍵（ca.key）：公印を押す権限と能力
2. クライアント証明書の発行プロセス：
   - たとえ：パスポートの発行
   - クライアントの公開鍵：市民の個人情報（名前、生年月日など）
   - クライアントの秘密鍵：市民の指紋（本人だけが持つ固有の情報）
   - 証明書署名要求（CSR）：パスポート申請書
   - CAによる署名：公印を押すこと
3. クライアント証明書の検証：
   - たとえ：パスポートの真正性確認
   - VPNサーバー：入国管理官
   - CA証明書（公開鍵）：公印の見本
   - クライアント証明書：押印されたパスポート

プロセスの流れ：

1. クライアント証明書の作成：
   - 市民（クライアント）が個人情報（公開鍵）と指紋（秘密鍵）を準備
   - パスポート申請書（CSR）を作成し、政府（CA）に提出
   - 政府が申請書を確認し、公印（CAの秘密鍵で署名）を押してパスポート（クライアント証明書）を発行
2. VPN接続時の認証：
   - 入国管理官（VPNサーバー）がパスポート（クライアント証明書）を確認
   - 公印の見本（CA証明書）と照合して、パスポートが正規のものか確認
   - パスポートの個人情報と、実際の人物（クライアントの秘密鍵による認証）が一致するか確認
3. セキュリティの仕組み：
   - 公印（CAの公開鍵）は広く公開されているが、押す権限（CAの秘密鍵）は厳重に管理されている
   - パスポート（クライアント証明書）は公開情報だが、それを「所有」している証明（クライアントの秘密鍵）は本人だけが持っている

このシステムにより：
- 誰でも公印（CA証明書）を見ることができるが、偽造することはできない
- パスポート（クライアント証明書）を持っているだけでなく、本人であること（秘密鍵の所有）も証明する必要がある

この仕組みにより、VPN接続の両端（サーバーとクライアント）が互いの身元を確実に確認でき、安全な通信を確立することができます。

TODO: さらにサーバー証明書という概念もあり、VPNサーバー側の信頼性を保つ仕組みも必要とのこと。

### ACM

ACMとAWS VPNと証明書についての理解を深める。

AWS VPNで今回使用することを検討したのは下記で2点。個人開発の場合はクライアントVPN接続を選択する。
- Site-to-Site VPN接続: 企業や組織全体のオンプレミスネットワークをAWS VPCに接続するために使用されます。
- クライアントVPN接続: 個々のユーザー（クライアントPC）がリモートからAWS VPCに安全に接続するために使用されます。

VPNを使うにはクライアント認証をする必要があり、下記3点がある。今回は「相互認証 (証明書ベース)」を使用する。
- Active Directory 認証 (ユーザーベース)
- 相互認証 (証明書ベース)
- シングルサインオン (SAML ベースのフェデレーション認証) (ユーザーベース)
https://docs.aws.amazon.com/ja_jp/vpn/latest/clientvpn-admin/client-authentication.html

相互認証（証明書ベース）について、いくつかの重要なポイントを下記に記す。
1. サーバー証明書：
   - VPNサーバー（エンドポイント）の身元を証明するために使用されます。
   - AWS Certificate Manager (ACM) で管理されます。
   - ACMがパブリック証明書を発行しており、こちらを利用すると管理者が有効期限を管理する等の手間が省ける。


2. クライアント証明書：
   - 各VPNクライアント（ユーザー）の身元を証明するために使用されます。
   - 通常、自己署名証明書や独自のプライベート認証局 (CA) で発行された証明書を使用します。

3. 証明書の管理：
   - サーバー証明書とクライアント証明書の両方の有効期限を定期的に確認し、必要に応じて更新する必要があります。
   - クライアント証明書の失効管理も考慮する必要があります。

4. 設定プロセス：
   - サーバー証明書をACMにインポートまたは発行します。
   - クライアント証明書を発行し、VPNクライアントに配布します。
   - VPNエンドポイントの作成時に、サーバー証明書とクライアント証明書のルートCAを指定します。

5. セキュリティ上の利点：
   - ユーザー名とパスワードだけでなく、証明書も必要とするため、セキュリティが強化されます。
   - 証明書の失効管理により、アクセス制御をより細かく管理できます。



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

VPC 内に配置されたリソース（OpenSearchドメイン等）は、デフォルトでインターネットから直接アクセスすることはできません。  
セキュリティグループとネットワーク ACL は VPC 内のトラフィックを制御するためのもの。
なのでVPC内のリソースに、VPC外からアクセスするには、下記の手段を取る必要がある。
- VPN 接続
- AWS Direct Connect
- 踏み台サーバー（Bastion Host）
- NAT ゲートウェイ（アウトバウンドトラフィック用）

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


### その他

自分のパブリックIPを調べる方法
```
curl ifconfig.me
```

ファイルを検索する
```
find . -name "*client1*" 
```

terraformのリソース関係図を出力する。
```
terraform graph -draw-cycles | dot -Tpng > graph.png
```

### TODO
・Route53の理解をする。
・何か管理画面とかを作るときはmobbinかFigrが参考になりそう。

