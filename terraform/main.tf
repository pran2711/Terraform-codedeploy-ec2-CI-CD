provider "aws" {
  region = ""
  access_key = ""
  secret_key = ""
}

resource "aws_instance" "inst" {
  ami = "ami-01a4f99c4ac11b03c"
  instance_type = "t2.micro"
  key_name = "mac"
  associate_public_ip_address = true


  tags = {
    Name = "myinsta"
  }
}


resource "aws_iam_role" "example" {
  name = "example-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "codedeploy.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "AWSCodeDeployRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
  role       = aws_iam_role.example.name
}


resource "aws_codedeploy_app" "example" {
  name = "myapp"
}

resource "aws_codedeploy_deployment_group" "name" {
  app_name  = "${aws_codedeploy_app.example.name}"
  deployment_group_name = "mygroup"
  service_role_arn = aws_iam_role.example.arn

  ec2_tag_set {
    ec2_tag_filter {
        key = "Name"
        type = "KEY_AND_VALUE"
        value = aws_instance.inst.tags["Name"]
    }
       ec2_tag_filter {
        key = "Name"
        type = "KEY_AND_VALUE"
        value = "mas"
    }
  }
  deployment_config_name = "CodeDeployDefault.HalfAtATime"

  depends_on = [
    aws_codedeploy_app.example
  ]
}


resource "aws_iam_policy" "codepipeline_policy" {
  name = "codepipeline_policy"
  path = "/"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "codedeploy:CreateDeployment",
                "codedeploy:GetApplicationRevision",
                "codedeploy:RegisterApplicationRevision",
                "s3:*",
                "codedeploy:GetDeploymentConfig",
                "codedeploy:GetDeployment",
                "ec2:*",
                "codedeploy:GetApplication"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_role" "codepipeline_role" {
  name = "test-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "attach_policy" {
  role = aws_iam_role.codepipeline_role.name
  policy_arn = aws_iam_policy.codepipeline_policy.arn
}

resource "aws_s3_bucket" "mybkt" {
  bucket = "asjcsdvcdvv"
  acl = "private"
}

resource "aws_codepipeline" "pipeline" {
  name = "ec2-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn


  artifact_store {
    location = aws_s3_bucket.mybkt.bucket
    type = "S3"
  }

  stage {
    name = "Source"

    action {
        name = "Source"
        category = "Source"
        owner = "ThirdParty"
        provider = "GitHub"
        version = "1"
        output_artifacts = ["SourceArtifact"]

        configuration = {
        Owner  = "pran2711"
        Repo   = "terraform-codedeploy-pipeline-ec2"
        Branch = "master"
       OAuthToken = "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"
      }
    }
  }

  stage {
    name = "Deploy"

    action {
        name = "Deploy"
        category = "Deploy"
        owner = "AWS"
        provider = "CodeDeploy"
        input_artifacts = [ "SourceArtifact" ]
        version = "1"

        configuration = {
            ApplicationName = "${aws_codedeploy_app.example.name}"
            DeploymentGroupName = "${aws_codedeploy_deployment_group.name.deployment_group_name}"
        }
    }
  }
}