import { S3Client, GetObjectCommand } from "@aws-sdk/client-s3";
import { Client } from "@opensearch-project/opensearch";
import { S3Event, S3Handler } from 'aws-lambda';

// S3クライアントを初期化
const s3Client = new S3Client({});

// OpenSearchクライアントを取得する
const getOpenSearchClient = async (): Promise<Client> => {
  // Dopplerの環境変数を取得
  const username = process.env.OPENSEARCH_USERNAME;
  const password = process.env.OPENSEARCH_PASSWORD;

  if (!username || !password) {
    throw new Error("OpenSearch credentials are not set in environment variables");
  }

  // OpenSearchクライアントを初期化
  return new Client({
    node: process.env.OPENSEARCH_ENDPOINT,
    auth: { username, password }
  });
};

export const handler: S3Handler = async (event: S3Event) => {
  // OpenSearchクライアントを取得
  const osClient = await getOpenSearchClient();

  // S3イベントの各レコードを処理
  for (const record of event.Records) {
    const bucket = record.s3.bucket.name;
    const key = decodeURIComponent(record.s3.object.key.replace(/\+/g, ' '));

    try {
      // S3からオブジェクトを取得
      const { Body } = await s3Client.send(new GetObjectCommand({ Bucket: bucket, Key: key }));
      const content = await Body?.transformToString();

      if (content) {
        // OpenSearchにドキュメントをインデックス
        await osClient.index({
          index: 'documents',
          body: {
            content: content,
            filename: key,
            timestamp: new Date()
          }
        });
        console.log(`Indexed document: ${key}`);
      }
    } catch (error) {
      console.error(`Error processing file ${key}:`, error);
    }
  }

  console.log("OK");
};
