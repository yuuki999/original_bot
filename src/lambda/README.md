## npmパッケージについて

型宣言でエラーになる場合は、下記でインストール
```
pnpm add aws-lambda
pnpm add -D @types/aws-lambda // 型指定、DオプションはdevDependenciesセクションに追加されます。開発中しか使われない。
```

パッケージを削除
```
pnpm remove package-name
```

パッケージ一覧を表示
```
pnpm list
```

スクリプトを実施
```
pnpm run script-name
```

package.jsonに記述された依存関係をインストールする。
```
pnpm i
```
