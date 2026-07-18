terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-2"
}

# IAM User - security-admin
resource "aws_iam_user" "security_admin" {
  name = "security-admin"
}

resource "aws_iam_user_policy_attachment" "admin_access" {
  user       = aws_iam_user.security_admin.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_user_policy" "assume_roles" {
  name = "AssumeSecurityAuditRoles"
  user = aws_iam_user.security_admin.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Resource = [
          "arn:aws:iam::119317299406:role/SecurityAuditRole",
          "arn:aws:iam::752575507907:role/SecurityAuditRole",
          "arn:aws:iam::182254551536:role/SecurityAuditRole",
          "arn:aws:iam::066756667315:role/SecurityAuditRole",
          "arn:aws:iam::119317299406:role/IncidentResponseRole",
          "arn:aws:iam::752575507907:role/IncidentResponseRole",
          "arn:aws:iam::182254551536:role/IncidentResponseRole",
          "arn:aws:iam::066756667315:role/IncidentResponseRole"
        ]
      }
    ]
  })
}

# CloudTrail
resource "aws_cloudtrail" "main" {
  name                          = "management-account-trail"
  s3_bucket_name                = "cloudtrail-logs-central-686316017813"
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }
}