# APPLY.md contract (for agents)

Parse the YAML frontmatter, run the listed preflight, obey `DECISION=`.

| Key | Meaning |
|---|---|
| `apply_when` | All must hold |
| `do_not_apply_when` | Any match → `SKIP` |
| `block_when` | Any match → `BLOCK` |
| `requires.env` | Env for the one-shot. Never persist `RUNNER_TOKEN` |
| `requires.privileges` | `root` or `administrator` |
| `reboot` | `never` \| `maybe` \| `always` |
| `scripts.preflight` | `KEY=value` facts + last line `DECISION=` |
| `scripts.install` | One-shot |
| `scripts.verify` | Listener is up |

```
os=linux
distro=ubuntu
version=24.04
kernel=6.8.0-138-generic
profile=docker-jobs
already_configured=false
listeners=0
DECISION=APPLY
```

| Decision | Exit | Action |
|---|---|---|
| `APPLY` | 0 | Run the one-shot |
| `SKIP` | 0 | Do not change the host |
| `BLOCK` | 2 | Do not change the host; report `reason=` |

`reason=` is comma-separated `snake_case`.
