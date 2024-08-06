import { BedrockRuntimeClient, InvokeModelCommand } from "@aws-sdk/client-bedrock-runtime";
import { Client } from "@opensearch-project/opensearch";
import { APIGatewayProxyEvent, APIGatewayProxyResult } from "aws-lambda";

// 環境変数の取得
const BEDROCK_MODEL_ID = process.env.BEDROCK_MODEL_ID || "anthropic.claude-3-sonnet-20240229-v1:0";
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

export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
  try {
    const userInput = JSON.parse(event.body || "{}").query; // ユーザー文字列
    const bedrock_query = await generateOpenSearchQuery(userInput); // クエリ作成
    const searchResults = await searchOpenSearch(bedrock_query); // 検索
    const finalResponse = await generateHumanReadableResponse(searchResults);

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
async function generateOpenSearchQuery(userInput: string): Promise<string> {
  const command = new InvokeModelCommand({
    modelId: BEDROCK_MODEL_ID,
    body: JSON.stringify({
      prompt: `Convert this user query into an OpenSearch query: ${userInput}`,
      max_tokens: BEDROCK_MAX_TOKENS, // botの生成クエリ最大文字数
    }),
  });

  const response = await bedrockClient.send(command);
  const responseBody = JSON.parse(new TextDecoder().decode(response.body));
  return responseBody.completion;
}

// OpenSearch内を検索する。
async function searchOpenSearch(query: string): Promise<any> {
  const response = await openSearchClient.search({
    index: OPENSEARCH_INDEX,
    body: JSON.parse(query),
  });
  return response.body.hits.hits;
}

// OpenSearchの検索結果を、Bedrockで人間が理解しやすい形式に変換。
async function generateHumanReadableResponse(searchResults: any): Promise<string> {
  const command = new InvokeModelCommand({
    modelId: BEDROCK_MODEL_ID,
    body: JSON.stringify({
      prompt: `Generate a human-readable response based on these search results: ${JSON.stringify(searchResults)}`,
      max_tokens: BEDROCK_MAX_TOKENS, // botの最大回答文字数
    }),
  });

  const response = await bedrockClient.send(command);
  const responseBody = JSON.parse(new TextDecoder().decode(response.body));
  return responseBody.completion;
}
