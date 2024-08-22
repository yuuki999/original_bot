import { BedrockRuntimeClient, InvokeModelCommand } from "@aws-sdk/client-bedrock-runtime";
import { Client } from "@opensearch-project/opensearch";
import { APIGatewayProxyEvent, APIGatewayProxyResult } from "aws-lambda";
import { AwsSigv4Signer } from "@opensearch-project/opensearch/aws";
import { defaultProvider } from "@aws-sdk/credential-provider-node";

// 環境変数の取得
const BEDROCK_MODEL_ID = process.env.BEDROCK_MODEL_ID || "anthropic.claude-3-5-sonnet-20240620-v1:0";
const OPENSEARCH_INDEX = process.env.OPENSEARCH_INDEX || "documents";
const BEDROCK_MAX_TOKENS = parseInt(process.env.BEDROCK_MAX_TOKENS || "1000", 10);

// Bedrock clientの設定をVPC対応に更新(異なるリージョンで繋ぐため)
const bedrockClient = new BedrockRuntimeClient({ 
  region: "us-east-1",
  endpoint: process.env.BEDROCK_ENDPOINT // VPC内のBedrockエンドポイント
});

const openSearchClient = new Client({
  node: process.env.OPENSEARCH_ENDPOINT,
  auth: {
    username: process.env.OPENSEARCH_USERNAME!,
    password: process.env.OPENSEARCH_PASSWORD!,
  },
});

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

export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
  try {
    const userInput = JSON.parse(event.body || "{}").query;
    console.log("ユーザーの入力:", userInput);

    const bedrock_query = await generateOpenSearchQuery(userInput);
    console.log("AIにより作成されたクエリ:", bedrock_query);

    const searchResults = await searchOpenSearch(bedrock_query);
    console.log("OpenSearchからの結果:", searchResults);

    const finalResponse = await generateHumanReadableResponse(searchResults);
    console.log("AIの回答結果:", finalResponse);

    return {
      statusCode: 200,
      body: JSON.stringify({ response: finalResponse }),
    };
  } catch (error) {
    console.error("Error:", error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: "Internal Server Error" }),
    };
  }
};

// ユーザーの問い合わせを、OpenSearchのクエリに変換する。
// TODO: ここの精度があまり良くない。opensearchの構造や、ヒントを与えてクエリの精度を上げる方法を調査する。
// クエリに_allを使用するのは負荷の観点から避けるべき。
// { "query": { "match": { "_all": "社内の文書" } } }
// TODO: botの会話の履歴をdynamoDBとかに保存して、学習させることで精度を上げる方法もある。
// https://blog.serverworks.co.jp/bedrock_chatbot_assistant
async function generateOpenSearchQuery(userInput: string): Promise<string> {
  const command = new InvokeModelCommand({
    modelId: BEDROCK_MODEL_ID,
    body: JSON.stringify({
      anthropic_version: "bedrock-2023-05-31",
      max_tokens: BEDROCK_MAX_TOKENS, // botの生成クエリ最大文字数
      messages: [
        { role: "user", content: `Generate an OpenSearch query for the following user input. Return ONLY the JSON query without any explanation or markdown formatting: ${userInput}` }
      ]
    }),
  });

  const response = await bedrockClient.send(command);
  const responseBody = JSON.parse(new TextDecoder().decode(response.body));
  
  // AIがJSONを返却してくれるので、念の為JSONを取り出す処理。
  if (responseBody.content && responseBody.content[0] && responseBody.content[0].text) {
    const text = responseBody.content[0].text.trim();
    // JSON部分を抽出するための正規表現
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (jsonMatch) {
      return jsonMatch[0];
    } else {
      console.error("No valid JSON found in the response:", text);
      throw new Error("Failed to generate valid OpenSearch query");
    }
  } else {
    console.error("Unexpected response format from Bedrock:", responseBody);
    throw new Error("Failed to generate OpenSearch query");
  }
}

// OpenSearch内を検索する。
async function searchOpenSearch(query: string): Promise<any> {
  console.log("Received query:", query); // デバッグ用ログ

  let parsedQuery;
  try {
    parsedQuery = JSON.parse(query);
  } catch (error) {
    console.error("Failed to parse query:", error);
    console.error("Raw query:", query);
    throw new Error("Invalid OpenSearch query format");
  }

  try {
    const client = await getOpenSearchClient();
    const response = await client.search({
      index: OPENSEARCH_INDEX,
      body: parsedQuery,
    });
    return response.body.hits.hits;
  } catch (error) {
    console.error("OpenSearch error:", error);
    console.error("OpenSearch request details:", {
      index: OPENSEARCH_INDEX,
      body: parsedQuery,
    });
    throw new Error("Failed to execute OpenSearch query");
  }
}

// OpenSearchの検索結果を、Bedrockで人間が理解しやすい形式に変換。
async function generateHumanReadableResponse(searchResults: any): Promise<string> {
  const command = new InvokeModelCommand({
    modelId: BEDROCK_MODEL_ID,
    body: JSON.stringify({
      anthropic_version: "bedrock-2023-05-31",
      max_tokens: BEDROCK_MAX_TOKENS, // botの生成クエリ最大文字数
      messages: [
        { role: "user", content: `以下の検索結果に基づいて、日本語で人間が読みやすい応答を生成してください。検索結果: ${JSON.stringify(searchResults)}` }
      ]
    }),
  });

  const response = await bedrockClient.send(command);
  const responseBody = JSON.parse(new TextDecoder().decode(response.body));
  
  if (responseBody.content && responseBody.content[0] && responseBody.content[0].text) {
    return responseBody.content[0].text;
  } else {
    console.error("Unexpected response format from Bedrock:", responseBody);
    throw new Error("日本語の応答の生成に失敗しました");
  }
}
