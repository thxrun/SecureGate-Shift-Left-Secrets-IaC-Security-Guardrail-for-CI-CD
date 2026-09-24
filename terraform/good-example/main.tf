resource "aws_security_group" "good_sg" {
  name        = "restricted-sg"
  description = "SG restricted to trusted CIDR"

  ingress {
    description = "SSH from trusted network only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["203.0.113.0/24"]
  }
}

resource "aws_s3_bucket" "good_bucket" {
  bucket = "securegate-demo-bucket-secure"
}

resource "aws_s3_bucket_versioning" "good_bucket_versioning" {
  bucket = aws_s3_bucket.good_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "good_bucket_encryption" {
  bucket = aws_s3_bucket.good_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "good_bucket_pab" {
  bucket                  = aws_s3_bucket.good_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}