#!/bin/bash

# すべてのLambda関数をビルド
for lambda in src/lambda/*/
do
  echo "Building $(basename "$lambda")..."
  (cd "$lambda" && bun run build)
done
