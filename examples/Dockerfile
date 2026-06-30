# syntax=docker/dockerfile:1
#
# Coder workspace image with Anthropic's `ant` CLI pre-installed.
#
# Build:
#   docker build -t <your-registry>/coder-anthropic-sandbox:latest examples/
#
# Then push to the registry you reference from `examples/main.tf` (or your own
# template). The Coder dispatcher creates a fresh workspace per Anthropic
# session from a template that uses this image; the module's `run.sh`
# invokes `ant beta:worker run` against the ANTHROPIC_* env vars the
# dispatcher injects per build.

FROM codercom/enterprise-base:ubuntu

# Upstream ant CLI release. Bump when a new release ships at
# https://github.com/anthropics/anthropic-cli/releases.
ARG ANT_VERSION=1.14.0

USER root

# Use apt's local-deb install so any dynamic dependencies (libc shims, etc.)
# resolve from the Ubuntu archive instead of failing dpkg with unmet deps.
# Upstream's .deb installs the binary at /usr/ant rather than /usr/bin/ant
# (https://github.com/anthropics/anthropic-cli/issues), so symlink it onto
# PATH before verifying. dpkg still owns the package for later upgrades.
RUN set -eux; \
	cd /tmp; \
	curl -fSL -o ant.deb \
		"https://github.com/anthropics/anthropic-cli/releases/download/v${ANT_VERSION}/ant_${ANT_VERSION}_linux_amd64.deb"; \
	apt-get update; \
	apt-get install -y --no-install-recommends ./ant.deb; \
	ln -sf /usr/ant /usr/local/bin/ant; \
	rm -f ant.deb; \
	apt-get clean; \
	rm -rf /var/lib/apt/lists/*; \
	ant --version

USER coder
