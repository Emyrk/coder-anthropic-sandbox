terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    docker = {
      source = "kreuzwerker/docker"
    }
  }
}

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

# Docker image with the `ant` CLI installed. Defaults to the reference image
# built and pushed from the sibling Dockerfile
# (docker.io/emyrk/coder-anthropic-sandbox). Override on `coder templates
# push` or via a tfvars file to point at your own registry.
variable "image" {
  type        = string
  description = "Docker image with the ant CLI pre-installed (built from ./Dockerfile)."
  default     = "emyrk/coder-anthropic-sandbox:latest"
}

resource "coder_agent" "main" {
  arch           = "amd64"
  os             = "linux"
  startup_script = <<-EOT
    set -e
    mkdir -p /home/coder/work
  EOT
}

# Wire ANTHROPIC_* env vars onto the agent and run the inner ant runner at
# agent start. The Coder dispatcher fills the five ephemeral parameters per
# build when it claims a work item from Anthropic.
module "anthropic" {
  source            = "../"
  agent_id          = coder_agent.main.id
  working_directory = "/home/coder/work"
}

resource "docker_container" "workspace" {
  count      = data.coder_workspace.me.start_count
  image      = var.image
  name       = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"
  hostname   = data.coder_workspace.me.name
  env        = ["CODER_AGENT_TOKEN=${coder_agent.main.token}"]
  entrypoint = ["sh", "-c", coder_agent.main.init_script]
}
