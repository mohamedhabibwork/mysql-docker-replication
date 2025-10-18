# Contributing

Thanks for taking the time to contribute! This project focuses on providing a reliable MySQL replication sandbox. The guidelines below help keep contributions consistent and maintainable.

## Code of Conduct

Please be respectful and collaborative. Assume good intent during reviews and discussions. Report unacceptable behavior via GitHub issues.

## Ways to Help

- Bug reports accompanied by reproduction steps and logs
- Feature requests that improve automation, observability, or security
- Pull requests fixing documentation gaps or typos
- Enhancements that keep the stack aligned with recent MySQL or Docker releases

## Getting Started

1. Fork the repository and create a feature branch (`git checkout -b feature/my-improvement`).
2. Copy `.env.example` files and adjust values for local testing.
3. Run `./mange.sh start` to validate changes locally. Add regression tests or scripts when practical.
4. Run `./mange.sh stop` before committing to ensure clean shutdown.

## Contribution Checklist

- [ ] Update or add documentation in `docs/` as needed.
- [ ] Include tests or manual verification steps in the pull request description.
- [ ] Ensure shell scripts pass `shellcheck` if modified (`shellcheck generate-ssl-certs.sh mange.sh`).
- [ ] Run `./mange.sh start` followed by `./mange.sh status` to confirm replication works.

## Pull Requests

- Use the provided pull request template; fill in all sections.
- Keep changes focused. Submit separate PRs for unrelated fixes.
- Expect reviewer feedback. Address comments promptly or explain alternate approaches.

## Release Process

When cutting a tagged release (future enhancement):

1. Update documentation (README, docs/) with new instructions.
2. Bump version numbers in scripts or metadata if applicable.
3. Draft release notes summarizing key changes and compatibility notes.

Thanks again for contributing!
