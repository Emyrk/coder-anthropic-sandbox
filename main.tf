terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
  }
}

variable "agent_id" {
  type        = string
  description = "ID of the coder_agent that should receive the ANTHROPIC_* env vars and the session-runner startup script."
}

variable "command" {
  type        = string
  default     = "ant beta:agent run"
  description = "Inner-side command invoked when a work item arrives. The ANTHROPIC_* env vars set by this module are in scope. Defaults to the ant Managed Agents inner runner; verify against the `ant` CLI version installed in your image before pinning to production."
}

variable "working_directory" {
  type        = string
  default     = ""
  description = "Working directory the command is run in. Empty means the coder_agent's default."
}

variable "done_file" {
  type        = string
  default     = "/tmp/anthropic-session.done"
  description = "File path the runner script touches when the command exits. Coderd watches for this file to know the session is finished and the workspace can be torn down."
}

variable "base_url" {
  type        = string
  default     = null
  description = "Pin the Anthropic base URL at the template level. When null (default), this module exposes the value as the ephemeral `anthropic_base_url` parameter so the dispatcher can override per build."
}

# Ephemeral, mutable parameters. Coderd's WorkspaceDispatcher fills these
# in per workspace build via rich_parameter_values when it claims a work
# item from Anthropic. Defaults are empty so manual builds (e.g. for
# inspection) still succeed; the runner script noops when no session is
# present.

data "coder_parameter" "session_id" {
  name         = "anthropic_session_id"
  display_name = "Anthropic session ID"
  description  = "Session ID this workspace will execute (sesn_...). Filled by the Coder dispatcher; leave blank for an idle workspace."
  type         = "string"
  ephemeral    = true
  mutable      = true
  default      = ""
  order        = 1000
}

data "coder_parameter" "work_id" {
  name         = "anthropic_work_id"
  display_name = "Anthropic work ID"
  description  = "Work-item ID the dispatcher claimed (work_...). Tied to a single session and set per build."
  type         = "string"
  ephemeral    = true
  mutable      = true
  default      = ""
  order        = 1001
}

data "coder_parameter" "environment_id" {
  name         = "anthropic_environment_id"
  display_name = "Anthropic environment ID"
  description  = "Self-hosted environment ID (env_...). One per Coder organization in the PoC."
  type         = "string"
  ephemeral    = true
  mutable      = true
  default      = ""
  order        = 1002
}

data "coder_parameter" "environment_key" {
  name         = "anthropic_environment_key"
  display_name = "Anthropic environment key"
  description  = "Env-wide work-queue credential (sk-ant-oat01-...). WIDE SCOPE: this key can read all sessions in the environment. See README.md for the per-work-item JWT alternative."
  type         = "string"
  ephemeral    = true
  mutable      = true
  default      = ""
  order        = 1003
}

data "coder_parameter" "base_url" {
  count        = var.base_url == null ? 1 : 0
  name         = "anthropic_base_url"
  display_name = "Anthropic base URL"
  description  = "API base URL the inner runner talks to. Override when pointing at a staging environment or a recording proxy."
  type         = "string"
  ephemeral    = true
  mutable      = true
  default      = "https://api.anthropic.com"
  order        = 1004
}

locals {
  base_url = coalesce(var.base_url, try(data.coder_parameter.base_url[0].value, "https://api.anthropic.com"))
}

resource "coder_env" "session_id" {
  agent_id = var.agent_id
  name     = "ANTHROPIC_SESSION_ID"
  value    = data.coder_parameter.session_id.value
}

resource "coder_env" "work_id" {
  agent_id = var.agent_id
  name     = "ANTHROPIC_WORK_ID"
  value    = data.coder_parameter.work_id.value
}

resource "coder_env" "environment_id" {
  agent_id = var.agent_id
  name     = "ANTHROPIC_ENVIRONMENT_ID"
  value    = data.coder_parameter.environment_id.value
}

resource "coder_env" "environment_key" {
  agent_id = var.agent_id
  name     = "ANTHROPIC_ENVIRONMENT_KEY"
  value    = data.coder_parameter.environment_key.value
}

resource "coder_env" "base_url" {
  agent_id = var.agent_id
  name     = "ANTHROPIC_BASE_URL"
  value    = local.base_url
}

resource "coder_script" "session" {
  agent_id     = var.agent_id
  display_name = "Anthropic session"
  icon         = "/emojis/1f916.png"
  run_on_start = true
  script = templatefile("${path.module}/run.sh", {
    command           = var.command
    working_directory = var.working_directory
    done_file         = var.done_file
  })
}

output "session_id" {
  description = "Anthropic session ID this workspace is bound to, or empty if the workspace was created without a session (e.g., a manual build)."
  value       = data.coder_parameter.session_id.value
}

output "done_file" {
  description = "Path the runner script touches when the inner command exits. Coderd watches this file to detect session completion."
  value       = var.done_file
}
