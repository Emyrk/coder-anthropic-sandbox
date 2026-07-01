# coder-anthropic-sandbox

Terraform module that wires a Coder agent to Anthropic's Managed Agents
self-hosted-sandbox worker protocol.

Drop the module into any Coder template (Docker, Kubernetes, VM,
anything that produces a `coder_agent`). When Coder's
`WorkspaceDispatcher` provisions a workspace from this template in
response to a claimed Anthropic work item, the module:

1. Declares five ephemeral `coder_parameter`s, one for each
   `ANTHROPIC_*` value the dispatcher passes per build.
2. Exposes them on the agent as `coder_env` resources.
3. Runs the configured inner command (default `ant beta:worker run`) at
   agent start with those env vars set.
4. Touches a done file when the command exits so the dispatcher can
   detect session completion.

The module is read-only on the Coder side: it consumes parameters and
sets environment, but does not call back into the dispatcher.

## Usage

```hcl
module "anthropic" {
  source            = "git::https://github.com/Emyrk/coder-anthropic-sandbox.git"
  agent_id          = coder_agent.main.id
  working_directory = "/home/coder"
}
```

Then ensure your container/VM image has the `ant` CLI installed. See
[`examples/Dockerfile`](./examples/Dockerfile) for a reference image
that installs `ant` from the upstream Debian package. The module does
not install `ant` for you; it only wires the env vars and runs
`var.command`.

## Inputs

| Name              | Default                       | Description                                                                                   |
|-------------------|-------------------------------|-----------------------------------------------------------------------------------------------|
| `agent_id`        | required                      | ID of the `coder_agent` to wire.                                                              |
| `command`         | `ant beta:worker run`         | Inner-side command run when a work item arrives.                                              |
| `working_directory` | `""` (agent default)        | `cd` here before running `command`.                                                           |
| `done_file`       | `/tmp/anthropic-session.done` | File the runner touches when the command exits.                                               |
| `base_url`        | `null`                        | Pin the Anthropic base URL. When null, exposed as the ephemeral `anthropic_base_url` param.   |

## Ephemeral parameters (filled by the dispatcher)

| Parameter                  | Env var                       | Description                                                          |
|----------------------------|-------------------------------|----------------------------------------------------------------------|
| `anthropic_session_id`     | `ANTHROPIC_SESSION_ID`        | Session this workspace is bound to (`sesn_...`).                     |
| `anthropic_work_id`        | `ANTHROPIC_WORK_ID`           | Work item ID the dispatcher claimed (`work_...`).                    |
| `anthropic_environment_id` | `ANTHROPIC_ENVIRONMENT_ID`    | Self-hosted environment ID (`env_...`).                              |
| `anthropic_environment_key`| `ANTHROPIC_ENVIRONMENT_KEY`   | Env-wide work-queue credential. See the security note below.         |
| `anthropic_base_url`       | `ANTHROPIC_BASE_URL`          | API base URL. Default `https://api.anthropic.com`.                   |

Defaults are empty so a manual `coder create` (no parameters) builds a
workspace that idles via the runner script's no-session guard.

## Outputs

| Name         | Description                                                                          |
|--------------|--------------------------------------------------------------------------------------|
| `session_id` | The Anthropic session ID bound to this workspace, or empty for a manual build.       |
| `done_file`  | Path the runner script touches when the command exits.                               |

## Security note: env-wide key scope

`ANTHROPIC_ENVIRONMENT_KEY` is the org-wide work-queue credential. A
worker process inside the sandbox, given that key, could in principle
claim other sessions' work or call non-session APIs the sandbox does
not need. The current model trusts the inner runner to use only the
`ANTHROPIC_WORK_ID` / `ANTHROPIC_SESSION_ID` it was given.

The Anthropic SDK's per-work-item JWT (the `Secret` field on
`BetaSelfHostedWork`) is a tighter alternative. A follow-up to the
module would inject `ANTHROPIC_WORK_SECRET` instead of the env key and
adjust the inner runner accordingly. Tracked, not done.

## Verifying the inner command

`var.command` defaults to `ant beta:worker run`, verified against
`ant` v1.14.0. That subcommand reads the same five `ANTHROPIC_*` env
vars this module sets (see `ant beta:worker run --help`). When you
bump the pinned `ant` version in your image, re-run `ant --help` to
confirm the subcommand still exists and still consumes the same
environment variables. The Anthropic CLI's beta surface has churned
once already (the runner was named `ant beta:agent run` before
v1.9.0), so future renames are plausible.
