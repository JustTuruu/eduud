import { Injectable } from '@nestjs/common';
import { PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { randomUUID } from 'crypto';

@Injectable()
export class R2Service {
  private client = new S3Client({
    region: 'auto',
    endpoint: `https://${process.env.R2_ACCOUNT_ID}.r2.cloudflarestorage.com`,
    credentials: {
      accessKeyId: process.env.R2_ACCESS_KEY_ID ?? '',
      secretAccessKey: process.env.R2_SECRET_ACCESS_KEY ?? '',
    },
  });

  /** Flutter шууд upload хийх presigned PUT URL (5 мин хүчинтэй). */
  async presignUpload(prefix: 'avatars' | 'auctions', contentType: string) {
    const ext = contentType.split('/')[1] ?? 'bin';
    const key = `${prefix}/${randomUUID()}.${ext}`;
    const uploadUrl = await getSignedUrl(
      this.client,
      new PutObjectCommand({
        Bucket: process.env.R2_BUCKET,
        Key: key,
        ContentType: contentType,
      }),
      { expiresIn: 300 },
    );
    return { uploadUrl, key, publicUrl: `${process.env.R2_PUBLIC_URL}/${key}` };
  }
}
