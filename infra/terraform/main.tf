locals {
  region = "ap-northeast-1"
  aws_account_id = "981715094000"

  allowed_github_repositories = [
    "poker_app_deploy",
  ]
  github_name = "mjex11"
  full_paths = [
    for repo in local.allowed_github_repositories : "repo:${local.github_name}/${repo}:*"
  ]

  task_definition_task_role_name = "one-ecs-service-20230511144726561200000004"
  task_definition_task_execution_role_name = "one-ecs-service-20230511144726556900000003"
  ecs_service_name = "one-ecs-service"
  ecs_cluster_name = "one-ecs-cluster"
}

# see: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc_verify-thumbprint.html
# see: https://github.com/aws-actions/configure-aws-credentials/issues/357#issuecomment-1011642085
data "tls_certificate" "github_actions" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  # ref: https://qiita.com/minamijoyo/items/eac99e4b1ca0926c4310
  # ref: https://zenn.dev/yukin01/articles/github-actions-oidc-provider-terraform
  thumbprint_list = [data.tls_certificate.github_actions.certificates[0].sha1_fingerprint]
}

# GitHub Actions側からはこのIAM Roleを指定する
resource "aws_iam_role" "github_actions" {
  name               = "github-actions-role-poker_app_deploy"
  assume_role_policy = data.aws_iam_policy_document.github_actions.json
  description        = "IAM Role for GitHub Actions OIDC"
}

# see: https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services#configuring-the-role-and-trust-policy
data "aws_iam_policy_document" "github_actions" {
  statement {
    actions = [
      "sts:AssumeRoleWithWebIdentity",
    ]

    principals {
      type = "Federated"
      identifiers = [
        aws_iam_openid_connect_provider.github_actions.arn
      ]
    }

    # OIDCを利用できる対象のGitHub Repositoryを制限する
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.full_paths
    }
  }
}

resource "aws_iam_policy" "ecs_deploy" {
  name        = "ECSExcutionForOneEcsRole"
  description = "Allows to deploy the service to the ECS cluster and update the task definition in the ECR"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "RegisterTaskDefinition",
        Effect = "Allow",
        Action = [
          "ecs:RegisterTaskDefinition"
        ],
        "Resource" = "*"
      },
      {
        Sid = "PassRolesInTaskDefinition",
        Effect = "Allow",
        Action = [
          "iam:PassRole"
        ],
        Resource = [
          "arn:aws:iam::${local.aws_account_id}:role/${local.task_definition_task_role_name}",
          "arn:aws:iam::${local.aws_account_id}:role/${local.task_definition_task_execution_role_name}"
        ]
      },
      {
        Sid = "DeployService",
        Effect = "Allow",
        Action = [
          "ecs:UpdateService",
          "ecs:DescribeServices"
        ],
        "Resource":[
          "arn:aws:ecs:${local.region}:${local.aws_account_id}:service/${local.ecs_cluster_name}/${local.ecs_service_name}"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_deploy" {
  policy_arn = aws_iam_policy.ecs_deploy.arn
  role       = aws_iam_role.github_actions.name
}
