resource "aws_security_group" "bad_sg" {
  name        = "wide-open-sg"
  description = "insecure demo sg"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_s3_bucket" "bad_bucket" {
  bucket = "securegate-demo-bucket"
}