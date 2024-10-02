terraform {
  required_version = "1.9.7"
  backend "s3" {
    key            = "capra-playground/state.tfstate"
    bucket         = "<account-id>-terraform-state" # TODO: Din AWS konto-ID.
    dynamodb_table = "<account-id>-terraform-lock"  # TODO: Din AWS konto-ID.
    region         = "eu-west-1"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.60.0"
    }
  }
}

provider "aws" {
  region              = "eu-west-1"
  allowed_account_ids = ["<account-id>"] # TODO: Din AWS konto-ID.
}

locals {
  name_prefix = "capra-playground"
  email       = "<email>" # TODO: Din e-post
  tags = {
    project   = local.name_prefix
    terraform = true
  }
}

resource "aws_budgets_budget" "this" {
  name              = "${local.name_prefix}-monthly"
  budget_type       = "COST"
  limit_amount      = "50"
  limit_unit        = "USD"
  time_period_end   = "2087-06-15_00:00"
  time_period_start = "2017-07-01_00:00"
  time_unit         = "MONTHLY"
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [local.email]
  }
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [local.email]
  }
}
