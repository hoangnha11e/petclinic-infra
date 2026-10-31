data "terraform_remote_state" "terraform1" {
  backend = "s3"
  config = {
    bucket = "petclinic-terraform-state-732107786436-ap-southeast-1-an"
    key    = "terraform1/terraform.tfstate"
    region = "ap-southeast-1"
  }
}

data "aws_caller_identity" "current" {}