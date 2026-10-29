terraform {
    backend "s3" {
        bucket       = "petclinic-terraform-state-732107786436-ap-southeast-1-an"
        key          = "terraform1/terraform.tfstate"
        region       = "ap-southeast-1"
        use_lockfile = true
        encrypt      = true
    }
}