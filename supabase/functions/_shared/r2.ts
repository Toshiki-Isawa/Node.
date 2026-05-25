import { GetObjectCommand, PutObjectCommand, S3Client } from "npm:@aws-sdk/client-s3@3.700.0";
import { getSignedUrl } from "npm:@aws-sdk/s3-request-presigner@3.700.0";

const DEFAULT_EXPIRES_IN = 3600;

export type R2Config = {
  accountId: string;
  bucket: string;
  accessKeyId: string;
  secretAccessKey: string;
  publicBaseUrl?: string;
};

export function loadR2Config(): R2Config | null {
  const accountId = Deno.env.get("R2_ACCOUNT_ID") ?? "";
  const accessKeyId = Deno.env.get("R2_ACCESS_KEY_ID") ?? "";
  const secretAccessKey = Deno.env.get("R2_SECRET_ACCESS_KEY") ?? "";
  const bucket = Deno.env.get("R2_BUCKET") ?? "node-observations";
  const publicBaseUrl = Deno.env.get("R2_PUBLIC_BASE_URL") ?? undefined;

  if (!accountId || !accessKeyId || !secretAccessKey) {
    return null;
  }

  return { accountId, bucket, accessKeyId, secretAccessKey, publicBaseUrl };
}

function createR2Client(config: R2Config): S3Client {
  return new S3Client({
    region: "auto",
    endpoint: `https://${config.accountId}.r2.cloudflarestorage.com`,
    credentials: {
      accessKeyId: config.accessKeyId,
      secretAccessKey: config.secretAccessKey,
    },
  });
}

export async function presignPutObject(
  config: R2Config,
  key: string,
  contentType: string,
  expiresIn = DEFAULT_EXPIRES_IN,
): Promise<string> {
  const client = createR2Client(config);
  return getSignedUrl(
    client,
    new PutObjectCommand({
      Bucket: config.bucket,
      Key: key,
      ContentType: contentType,
    }),
    { expiresIn },
  );
}

export async function presignGetObject(
  config: R2Config,
  key: string,
  expiresIn = DEFAULT_EXPIRES_IN,
): Promise<string> {
  const client = createR2Client(config);
  return getSignedUrl(
    client,
    new GetObjectCommand({
      Bucket: config.bucket,
      Key: key,
    }),
    { expiresIn },
  );
}

export function publicObjectUrl(config: R2Config, key: string): string | null {
  if (!config.publicBaseUrl) return null;
  return `${config.publicBaseUrl.replace(/\/$/, "")}/${key}`;
}
