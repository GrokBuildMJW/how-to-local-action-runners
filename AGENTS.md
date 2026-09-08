# Agent instructions

Read the platform `APPLY.md`, run its preflight on the **target host**, obey
the last `DECISION=` line.

1. OS → [`linux/APPLY.md`](linux/APPLY.md) (and [`linux/KERNEL.md`](linux/KERNEL.md)),
   [`macos/APPLY.md`](macos/APPLY.md), or [`windows/APPLY.md`](windows/APPLY.md).
2. Hardware class → [`examples/`](examples/README.md) for **profile** only.
   `RUNNER_NAME` / `RUNNER_LABELS` from the human, or the placeholders there.
3. Preflight. Parse `DECISION=`.
4. `APPLY` → one-shot with `DEDICATED_RUNNER=1`, `GITHUB_URL`, `RUNNER_TOKEN`,
   `RUNNER_NAME`, `RUNNER_LABELS`.
5. `SKIP` → do not change the host.
6. `BLOCK` → do not change the host; report `reason=` (Linux: Ubuntu 26.04 /
   kernel 7.x for `docker-jobs`).
7. `REBOOT_REQUIRED=1` → reboot, re-run the same one-shot. Do not write the
   token to disk. If it expired, mint a new one.

- Do not apply on a daily-driver workstation unless the human set
  `DEDICATED_RUNNER=1` and said the box is CI-only.
- Do not disable AppArmor or pin a kernel except via the Linux `docker-jobs`
  one-shot on that CI box.
- Do not start a second `Runner.Listener`.
- Do not write `RUNNER_TOKEN` to a file.

| `PROFILE` | When |
|---|---|
| `docker-jobs` (Linux default) | Jobs start Docker / nested bubblewrap |
| `minimal` | Listener only |

If the human did not pick a Linux profile, ask.
