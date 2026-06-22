# LOG

- 2026-06-20: Initial review of mandatory Inception project — Docker Compose infrastructure (NGINX, WordPress, MariaDB)
- 2026-06-22: Full project review + fake evaluation — all mandatory + bonus services reviewed (redis, ftp, website/caddy, adminer, portainer). Grade prediction: PASS. Critical: secrets tracked in git (pre-eval fix needed). Major: volume bind-mount workaround + relative host paths. Minor: Redis dependency in WordPress, empty .dockerignore files, .env typo.
