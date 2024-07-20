# document_processor

bunを使用したかったが、lambdaがesmodule形式だと、エラーになる（対応していると思うが...）のでcommonJS形式で動作させる。  
bunだとアウトプットがesmodule形式になるので、pnpmを使用している。  
バンドラーはesbuildを使用してtsファイルをjsファイルに変換する。  
  
参考記事:
https://docs.aws.amazon.com/ja_jp/lambda/latest/dg/lambda-typescript.html

### ディレクトリ設計

```
original_bot/
├── src/
│   └── lambda/
│       ├── document_processor/
│       │   ├── src/
│       │   │   └── index.ts
│       │   ├── dist/
│       │   │   └── index.js
│       │   ├── tests/
│       │   │   └── index.test.ts
│       │   ├── events/
│       │   │   └── event.json
│       │   ├── package.json
│       │   ├── tsconfig.json
│       │   └── README.md
│       └── other_lambda_function/
│           ├── src/
│           ├── dist/
│           ├── tests/
│           ├── events/
│           ├── package.json
│           ├── tsconfig.json
│           └── README.md
├── terraform/
│   ├── modules/
│   │   ├── lambda/
│   │   ├── opensearch/
│   │   ├── s3/
│   │   └── vpc/
│   ├── environments/
│   │   ├── dev/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── terraform.tfvars
│   │   └── prod/
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       └── terraform.tfvars
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
└── scripts/
    ├── build_lambdas.sh
    └── deploy.sh
```

特にlambda関数ごとにpackage.jsonを持つのかどうかで疑問が発生したので調査。
一般的に、プロジェクトの規模や要件によって異なりますが、以下の2つのアプローチが最も一般的に使用されています：

1. モノレポアプローチ（中小規模プロジェクト向け）:

   多くの中小規模のプロジェクトでは、モノレポアプローチが好まれます。このアプローチは以下の理由で人気があります：

   - シンプルさ: 1つの`package.json`と`node_modules`で管理するため、セットアップと維持が容易です。
   - 依存関係の一貫性: すべての関数で同じバージョンの依存関係を使用するため、互換性の問題が少なくなります。
   - DRY（Don't Repeat Yourself）原則: 共通のコードや設定を簡単に共有できます。
   - CI/CDの簡素化: 単一のビルドプロセスで全ての関数をカバーできます。

2. Webpackやesbuildを使用した最適化アプローチ（大規模プロジェクト向け）:

   大規模プロジェクトや、パフォーマンスが特に重要な場合、このアプローチが選択されることが多いです：

   - 最小のデプロイサイズ: 各関数に必要な依存関係のみをバンドルするため、デプロイサイズを最小限に抑えられます。
   - 起動時間の改善: 小さなバンドルサイズにより、Lambda関数の起動時間が改善されます。
   - 柔軟性: 各関数ごとに異なる依存関係やバージョンを使用できます。

実際の選択基準：

1. プロジェクトの規模: 
   - 小～中規模 → モノレポ
   - 大規模 → 最適化アプローチ

2. チームの経験:
   - Webpackやesbuildに精通していない → モノレポ
   - ビルドツールに習熟している → 最適化アプローチ

3. 関数の数と複雑さ:
   - 少数の関連性の高い関数 → モノレポ
   - 多数の独立した関数 → 最適化アプローチ

4. デプロイ頻度:
   - 全体を頻繁にデプロイ → モノレポ
   - 個別の関数を独立してデプロイ → 最適化アプローチ

5. パフォーマンス要件:
   - 標準的 → モノレポ
   - 厳格 → 最適化アプローチ

多くの場合、プロジェクトは小規模なモノレポから始まり、必要に応じて最適化アプローチに移行していきます。また、これらのアプローチを組み合わせたハイブリッドな方法を採用するケースも増えています。例えば、モノレポ構造を維持しながら、デプロイ時にWebpackで最適化するといった方法です。

最終的には、プロジェクトの具体的な要件、チームの好み、そして将来の拡張性を考慮して、最適なアプローチを選択することが重要です。

### ビルド方法
typescriptをdistディレクトリにビルドする。
```
bun run build
```

typescriptをdistディレクトリにビルドして、zipファイル化する。（terraform planでもzipはされる。）
```
bun run package
```

### ローカルでのlambda関数の検証

ローカルでlambda関数をテストする時にはAWS SAM (Serverless Application Model) を使う。
```
brew tap aws/tap
brew install aws-sam-cli
```

installの確認
```
sam --version
```

AWS CLIをインストールしていない場合は設定する。
```
brew install awscli
```

AWS 認証情報の設定（まだ設定していない場合）
```
aws configure
```

lambda関数を実行する。
```
sam local invoke DocumentProcessorFunction --event events/event.json
sam local invoke DocumentProcessorFunction --event events/event.json | jq # jqがあればこれでログが多少見やすくなる。
```
下記のようなエラーが出る場合はdockerを起動する。  
<span style="color: #888888;">Error: Running AWS SAM projects locally requires Docker. Have you got it installed and running?</span>

全てのlambda関数をdistにビルドする方法、プロジェクトルートで下記を実行
```
./scripts/build_lambdas.sh
```


## その他

現在のディレクトリ構成を確認する方法
```
tree -C -I 'node_modules'
tree -C -I 'node_modules|dist'
tree -C -I '*test*'
```
