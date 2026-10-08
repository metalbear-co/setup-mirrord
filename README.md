# Setup mirrord

A GitHub Action that installs the [mirrord](https://metalbear.com/mirrord) CLI on the runner, pinned to a release of your choice, verified against the checksum published with that release, and cached so the next job does not download it again.

```yaml
- uses: metalbear-co/setup-mirrord@v1
  with:
    version: 3.271.0
    checksum: 224f8d2e45189422a98f3a9b7d989dc3718e755f7c2e6153a9fb170b6279ef24

- run: mirrord --version
```

## Inputs

| Input | Required | Description |
| --- | --- | --- |
| `version` | no | mirrord release to install, e.g. `3.271.0`. Defaults to the latest release. |
| `checksum` | no | Expected SHA-256 of the release asset for this runner (see below). The step fails when it does not match. |

## Outputs

| Output | Description |
| --- | --- |
| `version` | The release that was installed, also when `version` was left empty. |
| `path` | The directory holding the binary, already appended to `PATH`. |
| `cache-hit` | `true` when the binary came from the runner cache. |

## What is verified

Every mirrord release ships a checksum file next to each binary. The action downloads both, computes the SHA-256 of the asset and refuses to install when they differ, so a corrupt or tampered download never reaches `PATH`.

`checksum` goes one step further: it pins the exact bytes your workflow expects, so a republished release or a changed download cannot slip in. The value is the SHA-256 printed on the [release page](https://github.com/metalbear-co/mirrord/releases) for the asset of your runner:

| Runner | Asset the checksum covers |
| --- | --- |
| Linux x64 | `mirrord_linux_x86_64.zip` |
| Linux ARM64 | `mirrord_linux_aarch64.zip` |
| macOS | `mirrord_mac_universal.zip` |
| Windows | `mirrord.exe` |

A workflow that runs on several runner types keeps one checksum per type, for example through a matrix.

## Caching

The binary is cached with [`actions/cache`](https://github.com/actions/cache) under a key made of the runner OS, architecture, version and pinned checksum. The first job downloads and verifies, and saves the cache as soon as the binary passes verification; later jobs, and a second use within the same job, restore it. Changing the pinned checksum changes the key, so an old binary is never reused for a new pin.

## Latest release

Without `version` the action installs the newest release, which it reads from the `latest` tag of the mirrord repository. Pin a version for reproducible CI runs.

## License

MIT, see [LICENSE](LICENSE).
