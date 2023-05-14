locals {
  function_name = "pokerAppDeployFunction"
  ecr_repository_name = "one-ecs-ecr"
}

data "aws_iam_policy_document" "lambda_assume_role_policy"{
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name = "${local.function_name}lambda_role"

  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
}

data "aws_iam_policy" "lambda_basic_execution" {
  arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "lambda_policy" {
  source_policy_documents = [data.aws_iam_policy.lambda_basic_execution.policy]
}

resource "aws_iam_policy" "lambda_policy" {
  name   = "${local.function_name}Policy"
  policy = data.aws_iam_policy_document.lambda_policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

data "archive_file" "function_source" {
  type        = "zip"
  source_dir  = "../../app/lambda/deploy"
  output_path = "archive/lambda_function.zip"
}

resource "aws_lambda_function" "dispatch_github_event" {
  function_name = local.function_name
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"

  filename      = data.archive_file.function_source.output_path
  source_code_hash = data.archive_file.function_source.output_base64sha256

  runtime = "python3.10"

  environment {
    variables = {
      GITHUB_OWNER = var.github_owner
      GITHUB_REPO  = var.github_repo
      github_token = var.github_token
    }
  }
}

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name = "/aws/lambda/${local.function_name}"
}

resource "aws_cloudwatch_event_rule" "ecr_image_push" {
  name        = "ecr-image-push"
  description = "Fires when an image is pushed to ECR"

  event_pattern = <<PATTERN
{
  "source": ["aws.ecr"],
  "detail-type": ["ECR Image Action"],
  "detail": {
    "action-type": ["PUSH"],
    "result": ["SUCCESS"],
    "repository-name": ["${local.ecr_repository_name}"]
  }
}
PATTERN
}

resource "aws_cloudwatch_event_target" "send_to_lambda" {
  rule      = aws_cloudwatch_event_rule.ecr_image_push.name
  target_id = "SendToLambda"
  arn       = aws_lambda_function.dispatch_github_event.arn
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dispatch_github_event.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ecr_image_push.arn
}
