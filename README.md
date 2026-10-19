# neo-casaos

> A maintained fork of [CasaOS](https://github.com/IceWhaleTech/CasaOS) — the personal cloud for your home.

<p align="center">
    <!-- neo banner: drop your own artwork here (docs/banner-light.png, docs/banner-dark.png) -->
    <!-- <picture>
        <source media="(prefers-color-scheme: dark)" srcset="docs/banner-dark.png">
        <source media="(prefers-color-scheme: light)" srcset="docs/banner-light.png">
        <img alt="neo-casaos" src="docs/banner-light.png">
    </picture> -->
    <br/>
    <a href="https://github.com/Elephant-on-github/neo-casaos/releases" target="_blank">
        <img alt="neo-casaos version" src="https://img.shields.io/github/v/release/Elephant-on-github/neo-casaos?color=162453&style=flat-square&label=release" />
    </a>
    <a href="https://github.com/Elephant-on-github/neo-casaos/blob/main/LICENSE" target="_blank">
        <img alt="License" src="https://img.shields.io/github/license/Elephant-on-github/neo-casaos?color=162453&style=flat-square&label=license" />
    </a>
    <a href="https://github.com/Elephant-on-github/neo-casaos/pulls" target="_blank">
        <img alt="Pull requests" src="https://img.shields.io/github/issues-pr/Elephant-on-github/neo-casaos?color=162453&style=flat-square&label=PRs" />
    </a>
    <a href="https://github.com/Elephant-on-github/neo-casaos/issues" target="_blank">
        <img alt="Issues" src="https://img.shields.io/github/issues/Elephant-on-github/neo-casaos?color=162453&style=flat-square&label=issues" />
    </a>
    <a href="https://github.com/Elephant-on-github/neo-casaos/stargazers" target="_blank">
        <img alt="Stars" src="https://img.shields.io/github/stars/Elephant-on-github/neo-casaos?color=162453&style=flat-square&label=stars" />
    </a>
    <a href="https://codecov.io/gh/Elephant-on-github/neo-casaos" target="_blank">
        <img alt="Coverage" src="https://codecov.io/gh/Elephant-on-github/neo-casaos/branch/main/graph/badge.svg" />
    </a>
</p>

## What is this

Upstream CasaOS has gone quiet. This fork keeps it running and ships the fixes
users actually ask for — without waiting on a new release cycle, and without
depending on anyone's cloud services to keep working.

It is a drop-in replacement: your data, apps, shares and settings stay exactly
where they are.

### What's different

- **Revocable file share links** — generate a public URL for any file, revoke it later
- **Opt-in SMB authentication** — shares can require the `casaos-share` account instead of being world-readable
- **Show hidden files toggle** in the file browser
- **Self-hosted update channel** — version checks and releases live in this repo, not on someone else's API
- **No third-party service calls** — the backend no longer phones home to check for updates

### Repositories

| Repository | What it is |
|---|---|
| [neo-casaos](https://github.com/Elephant-on-github/neo-casaos) | Go backend — services, routes, models, build scripts |
| [neo-casaos-ui](https://github.com/Elephant-on-github/neo-casaos-ui) | Vue 3 frontend |
| [neo-casaos-gateway](https://github.com/Elephant-on-github/neo-casaos-gateway) | Go reverse proxy |

## Install

### On a fresh machine

```sh
curl -fsSL https://raw.githubusercontent.com/Elephant-on-github/neo-casaos/main/build/install.sh | sudo bash
```

Installs the full stack: the three neo components from this fork's releases
plus the CasaOS services that are not forked yet (message-bus, user-service,
local-storage, app-management, CLI, app store) from upstream. Sets the update
channel to neo, so the **Settings → Update** button pulls neo releases
afterwards.

### On an existing CasaOS install

```sh
curl -fsSL https://raw.githubusercontent.com/Elephant-on-github/neo-casaos/main/build/migrate.sh | sudo bash
```

Swaps in the neo components in place (data, databases and apps untouched),
points the update channel at this fork, and restarts CasaOS.

## Update

Through the UI (**Settings → Update**) or from a terminal:

```sh
curl -fsSL https://raw.githubusercontent.com/Elephant-on-github/neo-casaos/main/build/update.sh | sudo bash
```

## Releases

Assets are published on the [releases page](https://github.com/Elephant-on-github/neo-casaos/releases)
as `linux-<arch>-casaos-vX.Y.Z.tar.gz` for amd64, arm64 and arm-7. The UI and
gateway ship from their own repositories.

Release process: [docs/releasing.md](docs/releasing.md)

## Requirements

**Hardware** — amd64, arm64, armv7

**Systems** — Debian, Ubuntu, Raspberry Pi OS (tested) · others work but are untested

## Contributing

Issues and pull requests on this repo are welcome. For the development workflow,
see [the upstream contribution guide](https://wiki.casaos.io/en/contribute/development).

## Credits

This project is built on the work of the CasaOS community — see the contributor
list below. Licensed under [Apache 2.0](LICENSE).

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->
<table>
  <tr>
    <td align="center"><a href="https://github.com/jerrykuku"><img src="https://avatars.githubusercontent.com/u/9485680?v=4?s=100" width="100px;" alt=""/><br /><sub><b>老竭力</b></sub></a><br /><a href="https://github.com/IceWhaleTech/CasaOS/commits?author=jerrykuku" title="Code">💻</a> <a href="https://github.com/IceWhaleTech/CasaOS/commits?author=jerrykuku" title="Documentation">📖</a> <a href="#ideas-jerrykuku" title="Ideas, Planning, & Feedback">🤔</a> <a href="#infra-jerrykuku" title="Infrastructure (Hosting, Build-Tools, etc)">🚇</a> <a href="#maintenance-jerrykuku" title="Maintenance">🚧</a> <a href="#platform-jerrykuku" title="Packaging/porting to new platform">📦</a> <a href="#question-jerrykuku" title="Answering Questions">💬</a> <a href="https://github.com/IceWhaleTech/CasaOS/pulls?q=is%3Apr+reviewed-by%3Ajerrykuku" title="Reviewed Pull Requests">👀</a></td>
    <td align="center"><a href="https://github.com/LinkLeong"><img src="https://avatars.githubusercontent.com/u/13556972?v=4?s=100" width="100px;" alt=""/><br /><sub><b>link</b></sub></a><br /><a href="https://github.com/IceWhaleTech/CasaOS/commits?author=LinkLeong" title="Code">💻</a> <a href="https://github.com/IceWhaleTech/CasaOS/commits?author=LinkLeong" title="Documentation">📖</a> <a href="#ideas-LinkLeong" title="Ideas, Planning, & Feedback">🤔</a> <a href="#infra-LinkLeong" title="Infrastructure (Hosting, Build-Tools, etc)">🚇</a> <a href="#maintenance-LinkLeong" title="Maintenance">🚧</a> <a href="#question-LinkLeong" title="Answering Questions">💬</a> <a href="https://github.com/IceWhaleTech/CasaOS/pulls?q=is%3Apr+reviewed-by%3ALinkLeong" title="Reviewed Pull Requests">👀</a></td>
    <td align="center"><a href="https://github.com/tigerinus"><img src="https://avatars.githubusercontent.com/u/7172560?v=4?s=100" width="100px;" alt=""/><br /><sub><b>太戈</b></sub></a><br /><a href="https://github.com/IceWhaleTech/CasaOS/commits?author=tigerinus" title="Code">💻</a> <a href="https://github.com/IceWhaleTech/CasaOS/commits?author=tigerinus" title="Documentation">📖</a> <a href="#ideas-tigerinus" title="Ideas, Planning, & Feedback">🤔</a> <a href="#infra-tigerinus" title="Infrastructure (Hosting, Build-Tools, etc)">🚇</a> <a href="#maintenance-tigerinus" title="Maintenance">🚧</a> <a href="#mentoring-tigerinus" title="Mentoring">🧑‍🏫</a> <a href="#security-tigerinus" title="Security">🛡️</a> <a href="#question-tigerinus" title="Answering Questions">💬</a> <a href="https://github.com/IceWhaleTech/CasaOS/pulls?q=is%3Apr+reviewed-by%3Atigerinus" title="Reviewed Pull Requests">👀</a></td>
    <td align="center"><a href="https://github.com/Lauren-ED209"><img src="https://avatars.githubusercontent.com/u/8243355?v=4?s=100" width="100px;" alt=""/><br /><sub><b>Lauren</b></sub></a><br /><a href="#ideas-Lauren-ED209" title="Ideas, Planning, & Feedback">🤔</a> <a href="#fundingFinding-Lauren-ED209" title="Funding Finding">🔍</a> <a href="#projectManagement-Lauren-ED209" title="Project Management">📆</a> <a href="#question-Lauren-ED209" title="Answering Questions">💬</a> <a href="https://github.com/IceWhaleTech/CasaOS/commits?author=Lauren-ED209" title="Tests">⚠️</a></td>
    <td align="center"><a href="https://JohnGuan.Cn"><img src="https://avatars.githubusercontent.com/u/3358477?v=4?s=100" width="100px;" alt=""/><br /><sub><b>John Guan</b></sub></a><br /><a href="#blog-JohnGuan" title="Blogposts">📝</a> <a href="#content-JohnGuan" title="Content">🖋</a> <a href="https://github.com/IceWhaleTech/CasaOS/commits?author=JohnGuan" title="Documentation">📖</a> <a href="#ideas-JohnGuan" title="Ideas, Planning, & Feedback">🤔</a> <a href="#eventOrganizing-JohnGuan" title="Event Organizing">📋</a> <a href="#mentoring-JohnGuan" title="Mentoring">🧑‍🏫</a> <a href="#question-JohnGuan" title="Answering Questions">💬</a> <a href="https://github.com/IceWhaleTech/CasaOS/pulls?q=is%3Apr+reviewed-by%3AJohnGuan" title="Reviewed Pull Requests">👀</a></td>
    <td align="center"><a href="https://blog.tippybits.com"><img src="https://avatars.githubusercontent.com/u/17506770?v=4?s=100" width="100px;" alt=""/><br /><sub><b>David Tippett</b></sub></a><br /><a href="https://github.com/IceWhaleTech/CasaOS/commits?author=dtaivpp" title="Documentation">📖</a> <a href="#ideas-dtaivpp" title="Ideas, Planning, & Feedback">🤔</a> <a href="#question-dtaivpp" title="Answering Questions">💬</a></td>
    <td align="center"><a href="https://github.com/zarevskaya"><img src="https://avatars.githubusercontent.com/u/60230221?v=4?s=100" width="100px;" alt=""/><br /><sub><b>Skaya</b></sub></a><br /><a href="#mentoring-zarevskaya" title="Mentoring">🧑‍🏫</a> <a href="#question-zarevskaya" title="Answering Questions">💬</a> <a href="#tutorial-zarevskaya" title="Tutorials">✅</a> <a href="#translation-zarevskaya" title="Translation">🌍</a></td>
  </tr>
  <tr>
    <td align="center"><a href="https://github.com/AuthorShin"><img src="https://avatars.githubusercontent.com/u/4959043?v=4?s=100" width="100px;" alt=""/><br /><sub><b>AuthorShin</b></sub></a><br /><a href="https://github.com/IceWhaleTech/CasaOS/commits?author=AuthorShin" title="Tests">⚠️</a> <a href="https://github.com/IceWhaleTech/CasaOS/issues?q=author%3AAuthorShin" title="Bug reports">🐛</a> <a href="#question-AuthorShin" title="Answering Questions">💬</a> <a href="#ideas-AuthorShin" title="Ideas, Planning, & Feedback">🤔</a></td>
    <td align="center"><a href="https://github.com/baptiste313"><img src="https://avatars.githubusercontent.com/u/93325157?v=4?s=100" width="100px;" alt=""/><br /><sub><b>baptiste313</b></sub></a><br /><a href="#translation-baptiste313" title="Translation">🌍</a></td>
    <td align="center"><a href="https://github.com/DrMxrcy"><img src="https://avatars.githubusercontent.com/u/58747968?v=4?s=100" width="100px;" alt=""/><br /><sub><b>DrMxrcy</b></sub></a><br /><a href="https://github.com/IceWhaleTech/CasaOS/commits?author=DrMxrcy" title="Tests">⚠️</a> <a href="#ideas-DrMxrcy" title="Ideas, Planning, & Feedback">🤔</a> <a href="#question-DrMxrcy" title="Answering Questions">💬</a></td>
    <td align="center"><a href="https://github.com/Joooost"><img src="https://avatars.githubusercontent.com/u/12090673?v=4?s=100" width="100px;" alt=""/><br /><sub><b>Joooost</b></sub></a><br /><a href="#ideas-Joooost" title="Ideas, Planning, & Feedback">🤔</a></td>
    <td align="center"><a href="https://potyarkin.ml"><img src="https://avatars.githubusercontent.com/u/334908?v=4?s=100" width="100px;" alt=""/><br /><sub><b>Vitaly Potyarkin</b></sub></a><br /><a href="#ideas-sio" title="Ideas, Planning, & Feedback">🤔</a></td>
    <td align="center"><a href="https://github.com/bearfrieze"><img src="https://avatars.githubusercontent.com/u/1023813?v=4?s=100" width="100px;" alt=""/><br /><sub><b>Bjørn Friese</b></sub></a><br /><a href="#ideas-bearfrieze" title="Ideas, Planning, & Feedback">🤔</a></td>
    <td align="center"><a href="https://github.com/Protektor-Desura"><img src="https://avatars.githubusercontent.com/u/1195496?v=4?s=100" width="100px;" alt=""/><br /><sub><b>Protektor</b></sub></a><br /><a href="https://github.com/IceWhaleTech/CasaOS/issues?q=author%3AProtektor-Desura" title="Bug reports">🐛</a> <a href="#ideas-Protektor-Desura" title="Ideas, Planning, & Feedback">🤔</a> <a href="#question-Protektor-Desura" title="Answering Questions">💬</a></td>
  </tr>
  <tr>
    <td align="center"><a href="https://github.com/llwaini"><img src="https://avatars.githubusercontent.com/u/59589857?v=4?s=100" width="100px;" alt=""/><br /><sub><b>llwaini</b></sub></a><br /><a href="#projectManagement-llwaini" title="Project Management">📆</a> <a href="https://github.com/IceWhaleTech/CasaOS/commits?author=llwaini" title="Tests">⚠️</a> <a href="#tutorial-llwaini" title="Tutorials">✅</a></td>
    <td align="center"><a href="https://github.com/CorrectRoadH"><img src="https://avatars.githubusercontent.com/u/29306285?v=4?s=100" width="100px;" alt=""/><br /><sub><b>CorrectRoadH</b></sub></a><br /><a href="https://github.com/IceWhaleTech/CasaOS/commits?author=correctroadh" title="Code">💻</a> <a href="https://github.com/IceWhaleTech/CasaOS/commits?author=correctroadh" title="Documentation">📖</a></td>
    <td align="center"><a href="https://github.com/zhanghengxin"><img src="https://avatars.githubusercontent.com/u/24197448?v=4?s=100" width="100px;" alt=""/><br /><sub><b>zhanghengxin</b></sub></a><br /><a href="https://github.com/IceWhaleTech/CasaOS/commits?author=zhanghengxin" title="Code">💻</a> <a href="https://github.com/IceWhaleTech/CasaOS/commits?author=zhanghengxin" title="Documentation">📖</a></td>
  </tr>
</table>

<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->

<!-- ALL-CONTRIBUTORS-LIST:END -->

This project follows the [all-contributors](https://github.com/all-contributors/all-contributors) specification.

## Community

Questions and ideas: [GitHub Discussions](https://github.com/Elephant-on-github/neo-casaos/discussions)
or the [upstream Discord](https://discord.gg/knqAbbBbeX).

---

## Upstream CasaOS (original README)

<details>
<summary>Original CasaOS README (upstream, IceWhaleTech)</summary>

### CasaOS - Your Personal Cloud

#### Why do you need Personal Cloud?

In 2020, the team noticed three important trends:

- The cost of computing power and storage was decreasing fast.
- A part of cloud computing was moving towards edge computing.
- The issue of consumer data asset ownership and attribution had been ignored.

Based on these trends, the team proposed a thought experiment internally: what if
personal clouds were available under $100 in next five years? This personal cloud
would provide a low-cost data collaboration solution as a personal data center,
storing and managing data for creators and small organizations.

#### Features

- Friendly UI designed for home scenarios
- Multiple hardware and base system support
- Selected apps in the app store, one-click installation
- Easily install numerous Docker apps
- Elegant drive and file management
- Well-designed system/app widgets

#### Getting Started

```sh
wget -qO- https://get.casaos.io | sudo bash
```

#### Update CasaOS

```sh
wget -qO- https://get.casaos.io/update | sudo bash
```

#### Uninstall CasaOS

```sh
casaos-uninstall
```

#### Contributing

- See <https://wiki.casaos.io/en/contribute> for ways of contributing to CasaOS
- See <https://wiki.casaos.io/en/contribute/development> for code contributions

</details>
