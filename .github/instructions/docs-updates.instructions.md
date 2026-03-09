---
description: "Use when adding or changing Kubernetes infrastructure, services, applications, Helm charts, ingress, storage, or operational setup. Record relevant implementation details in docs/ as part of the same work."
---
# Document Relevant Changes

- Treat `docs/setup.md` as user-owned. Do not add to or edit that file unless the user explicitly asks for it.
- Prefer encoding reproducible operational behavior in checked-in manifests instead of prose. If a cluster default, chart override, or resource contract can be declared in Git, do that first.
- Save relevant implementation details to `docs/` only when they cannot be expressed directly in manifests and another operator would need the context later.
- Document the pieces another operator would need later: install steps, secret creation commands, external dependencies, upgrade notes, access URLs, and troubleshooting details.
- Prefer updating an existing page when the topic already exists. Create a new doc only when the change introduces a new operational area.
- Keep documentation concise and actionable. Focus on concrete steps and repo-specific decisions rather than generic Kubernetes explanations.