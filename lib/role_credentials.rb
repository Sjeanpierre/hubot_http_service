require 'aws-sdk'

class RoleCredentials
  # connect to S3 with role
  def role_credentials
    Aws::AssumeRoleCredentials.new(
      client: Aws::STS::Client.new,
      role_arn: "",
      role_session_name: "hubot-api-session"
    )
  end
end
