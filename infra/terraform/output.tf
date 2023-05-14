output "github_actions_oidc_provider_arn" {
  description = "The ARN of the AWS IAM OpenID Connect provider for GitHub Actions"
  value       = aws_iam_openid_connect_provider.github_actions.arn
}

output "github_actions_role_arn" {
  description = "The ARN of the AWS IAM role for GitHub Actions"
  value       = aws_iam_role.github_actions.arn
}

output "ecs_deploy_policy_arn" {
  description = "The ARN of the ECS deployment policy"
  value       = aws_iam_policy.ecs_deploy.arn
}
