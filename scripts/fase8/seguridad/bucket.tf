resource "aws_s3_bucket" "evidencias" {
  bucket = "evidencias-grupo-1"
}

resource "aws_s3_bucket_public_access_block" "evidencias" {
  bucket                  = aws_s3_bucket.evidencias.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}
