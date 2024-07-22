import { S3Client, GetObjectCommand } from "@aws-sdk/client-s3";
import { defaultProvider } from "@aws-sdk/credential-provider-node";
import { Client } from "@opensearch-project/opensearch";
import { S3Event, S3Handler } from 'aws-lambda';
import { AwsSigv4Signer } from "@opensearch-project/opensearch/aws";

// S3クライアントを初期化
const s3Client = new S3Client({});

// OpenSearchクライアントを取得する
const getOpenSearchClient = async (): Promise<Client> => {
  console.log('Initializing OpenSearch client');
  console.log('OpenSearch endpoint:', process.env.OPENSEARCH_ENDPOINT);
  console.log('AWS Region:', process.env.AWS_REGION);
  if (!process.env.AWS_REGION) {
    throw new Error("AWS_REGION is not set in the environment variables");
  }
  if (!process.env.OPENSEARCH_ENDPOINT) {
    throw new Error("OPENSEARCH_ENDPOINT is not set in the environment variables");
  }

  const signer = AwsSigv4Signer({
    region: process.env.AWS_REGION!, // lambdaの予約関数、https://docs.aws.amazon.com/ja_jp/lambda/latest/dg/configuration-envvars.html#configuration-envvars-runtime
    service: 'es', // OpenSearchを意味する。Elasticsearch Serviceの略
    getCredentials: () => defaultProvider()(), // AWS SDK の認証情報プロバイダを使用
  });

  console.log('AwsSigv4Signer initialized');

  return new Client({
    ...signer,
    node: process.env.OPENSEARCH_ENDPOINT!,
  });
};

export const handler: S3Handler = async (event: S3Event) => {
  // OpenSearchクライアントを取得
  let osClient: Client;
  try {
    osClient = await getOpenSearchClient();
  } catch (error) {
    console.error("Error initializing OpenSearch client:", error);
    throw error;
  }

  // S3イベントの各レコードを処理
  for (const record of event.Records) {
    const bucket = record.s3.bucket.name;
    const key = decodeURIComponent(record.s3.object.key.replace(/\+/g, ' '));

    try {
      // S3からオブジェクトを取得
      const { Body } = await s3Client.send(new GetObjectCommand({ Bucket: bucket, Key: key }));
      const content = await Body?.transformToString();

      console.log('Attempting to index document to OpenSearch');
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
