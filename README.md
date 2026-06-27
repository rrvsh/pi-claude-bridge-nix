# pi-claude-bridge-nix

Nix flake for a pinned, patched build of the Pi package [`@vanillagreen/pi-claude-bridge`](https://github.com/vanillagreencom/vstack/tree/d70c86ff9302ddecb7e2ae9d833bacb0544d6ecd/pi-extensions/pi-claude-bridge). The bridge is a [Pi package](https://github.com/earendil-works/pi/blob/622eca76089f9c3b1af358f8c7cfa7937fbe5b0a/packages/coding-agent/docs/packages.md#pi-packages) that registers a custom `claude-bridge` provider so Pi can send turns to Claude Code through the Claude Agent SDK while Pi keeps owning the TUI and tool execution.

This repository intentionally packages the bridge separately from [`rrvsh/pi-coding-agent-nix`](https://github.com/rrvsh/pi-coding-agent-nix): `pi-coding-agent-nix` provides the Pi CLI package itself, while this flake provides one Pi extension/provider package consumed by downstream host configuration.

## What this flake provides

- `packages.${system}.pi-claude-bridge` and `packages.${system}.default` for `aarch64-darwin` and `x86_64-linux` via [`flake.nix`](./flake.nix#L14-L20) and [`nix/pi-claude-bridge.nix`](./nix/pi-claude-bridge.nix#L8-L92).
- A source build from [`vanillagreencom/vstack`](https://github.com/vanillagreencom/vstack/tree/d70c86ff9302ddecb7e2ae9d833bacb0544d6ecd/pi-extensions/pi-claude-bridge), pinned by [`VERSION.json`](./VERSION.json#L1-L8).
- A Pi-package-shaped install tree at `lib/node_modules/@vanillagreen/pi-claude-bridge`, matching the upstream package name and Pi extension manifest. The install check verifies `package.json`, `bundle/index.js`, package name, version, and `pi.extensions = ["./bundle/index.js"]` in [`nix/pi-claude-bridge.nix`](./nix/pi-claude-bridge.nix#L45-L63).
- `passthru.packagePath`, used by downstream Nix config as a local package path, and a deterministic `passthru.tarball` for consumers that need an npm-style tarball shape ([derivation lines](./nix/pi-claude-bridge.nix#L65-L86)).
- A local runtime patch, [`patches/fix-multi-tool-results.patch`](./patches/fix-multi-tool-results.patch), applied before the bundle is built ([derivation line](./nix/pi-claude-bridge.nix#L27)).
- `packages.update` / `apps.update`, which refreshes the npm latest version, maps it to the upstream Git `gitHead`, recomputes `srcHash` and `npmDepsHash`, rewrites `VERSION.json`, and updates the flake lock ([`nix/update.nix`](./nix/update.nix#L5-L54)).
- GitHub Actions for Linux/Darwin builds ([`.github/workflows/build.yml`](./.github/workflows/build.yml#L12-L47)) and scheduled update PRs ([`.github/workflows/update.yml`](./.github/workflows/update.yml#L38-L104)).

## Relationship to upstream Pi and Claude Code

Pi package loading is documented upstream as package specs in settings and `pi install`, including npm, git, and local absolute/relative package paths ([Pi package docs](https://github.com/earendil-works/pi/blob/622eca76089f9c3b1af358f8c7cfa7937fbe5b0a/packages/coding-agent/docs/packages.md#install-and-manage), [package source docs](https://github.com/earendil-works/pi/blob/622eca76089f9c3b1af358f8c7cfa7937fbe5b0a/packages/coding-agent/docs/packages.md#package-sources)). A Pi package declares resources under the `pi` key in `package.json` ([Pi package structure docs](https://github.com/earendil-works/pi/blob/622eca76089f9c3b1af358f8c7cfa7937fbe5b0a/packages/coding-agent/docs/packages.md#creating-a-pi-package)). Upstream `@vanillagreen/pi-claude-bridge` does exactly that: its manifest declares `pi.extensions = ["./bundle/index.js"]` and metadata for Pi's extension manager ([upstream `package.json`](https://github.com/vanillagreencom/vstack/blob/d70c86ff9302ddecb7e2ae9d833bacb0544d6ecd/pi-extensions/pi-claude-bridge/package.json#L14-L19)).

Pi custom providers are registered by extensions through `pi.registerProvider()` ([Pi custom provider docs](https://github.com/earendil-works/pi/blob/622eca76089f9c3b1af358f8c7cfa7937fbe5b0a/packages/coding-agent/docs/custom-provider.md#custom-providers), [quick reference](https://github.com/earendil-works/pi/blob/622eca76089f9c3b1af358f8c7cfa7937fbe5b0a/packages/coding-agent/docs/custom-provider.md#quick-reference)). The bridge registers provider id `claude-bridge`, exposes `claude-bridge/*` models, and routes `streamSimple` to its Claude Agent SDK implementation in upstream `src/index.ts` ([provider registration](https://github.com/vanillagreencom/vstack/blob/d70c86ff9302ddecb7e2ae9d833bacb0544d6ecd/pi-extensions/pi-claude-bridge/src/index.ts#L2322-L2330)).

The upstream bridge calls the Claude Agent SDK `query()` API, constructs `queryOptions`, uses the `claude_code` preset prompt, disables Claude cloud MCP server auto-loading, and can point at an explicit `claude` executable ([upstream query setup](https://github.com/vanillagreencom/vstack/blob/d70c86ff9302ddecb7e2ae9d833bacb0544d6ecd/pi-extensions/pi-claude-bridge/src/index.ts#L1949-L1983)). See Anthropic's [Claude Code overview](https://code.claude.com/docs/en/overview) and [Agent SDK overview](https://code.claude.com/docs/en/agent-sdk/overview) for the upstream runtime this bridge talks to.

## Relationship to `pi-coding-agent-nix`

[`rrvsh/pi-coding-agent-nix`](https://github.com/rrvsh/pi-coding-agent-nix) packages the Pi CLI from `earendil-works/pi`; its derivation reads version/hash metadata from `VERSION.json` and exports `packages.pi-coding-agent` ([package derivation](https://github.com/rrvsh/pi-coding-agent-nix/blob/main/nix/pi-coding-agent.nix#L7-L20)). This repository mirrors that small-flake pattern but targets an extension package instead of the Pi CLI:

- both flakes use `flake-parts` plus `import-tree` and a tiny root `flake.nix` ([this flake](./flake.nix#L10-L20), [`pi-coding-agent-nix` flake](https://github.com/rrvsh/pi-coding-agent-nix/blob/main/flake.nix#L10-L18));
- both keep version and fixed-output hashes in `VERSION.json` ([this repo](./VERSION.json#L1-L8), [`pi-coding-agent-nix` metadata](https://github.com/rrvsh/pi-coding-agent-nix/blob/main/VERSION.json#L1-L5));
- both provide updater automation rather than relying on mutable registry installs ([this updater](./nix/update.nix#L20-L47), [`pi-coding-agent-nix` updater](https://github.com/rrvsh/pi-coding-agent-nix/blob/main/nix/update.nix#L1-L45)).

The separation matters operationally: updating Pi itself and updating the Claude bridge can be reviewed, built, rolled back, and pinned independently.

## How `tools` consumes this flake

The downstream [`rrvsh/tools`](https://github.com/rrvsh/tools) configuration owns Home Manager/system integration. It already installs Pi from `rrvsh/pi-coding-agent-nix`; the integration branch adds this bridge flake as `pi-claude-bridge` and follows the same `nixpkgs` input ([`tools/flake.nix`](https://github.com/rrvsh/tools/blob/pi-claude-bridge-nix-integration/flake.nix#L45-L50)). The Darwin Claude Code module then takes `inputs.pi-claude-bridge.packages.${system}.pi-claude-bridge`, reads `bridge.passthru.packagePath`, and places that Nix store package path in `programs.pi-coding-agent.settings.packages` ([`tools/nix/modules/claude-code.nix`](https://github.com/rrvsh/tools/blob/pi-claude-bridge-nix-integration/nix/modules/claude-code.nix#L1-L17)).

That downstream use depends on Pi's documented support for local package paths ([Pi local path package docs](https://github.com/earendil-works/pi/blob/622eca76089f9c3b1af358f8c7cfa7937fbe5b0a/packages/coding-agent/docs/packages.md#local-paths)). It avoids the previous mutable registry setting `npm:@vanillagreen/pi-claude-bridge` and lets `tools/flake.lock` pin the exact patched bridge commit.

## Package and update workflow

### Build and inspect

```sh
nix flake show --all-systems
nix build --print-build-logs .#pi-claude-bridge
ls -R result/lib/node_modules/@vanillagreen/pi-claude-bridge | head
```

The build runs upstream typechecking and focused unit tests ([`checkPhase`](./nix/pi-claude-bridge.nix#L36-L43)), then runs install checks against the Pi extension manifest ([`installCheckPhase`](./nix/pi-claude-bridge.nix#L45-L63)).

### Update upstream bridge

```sh
nix run .#update
git diff -- VERSION.json flake.lock
nix build --print-build-logs .#pi-claude-bridge
```

The updater reads latest npm metadata for `@vanillagreen/pi-claude-bridge`, requires `gitHead`, prefetches the corresponding GitHub source archive, computes npm dependency hashes from the upstream subdirectory lockfile, rewrites [`VERSION.json`](./VERSION.json#L1-L8), and runs `nix flake update` ([updater implementation](./nix/update.nix#L20-L47)). Review the patch application after updates because the local patch is intentionally carried out-of-tree.

### Validate before publishing

```sh
nix flake show --all-systems
nix build --print-build-logs .#packages.x86_64-linux.pi-claude-bridge
nix build --print-build-logs .#packages.aarch64-darwin.pi-claude-bridge  # on Darwin or a capable builder
git diff --check
```

CI runs equivalent per-system builds on push and pull requests ([build workflow](./.github/workflows/build.yml#L12-L50)). The build workflow authenticates to the `rrvsh` Cachix cache with `CACHIX_AUTH_TOKEN` and explicitly builds both `pi-claude-bridge.npmDeps` and `pi-claude-bridge` for `x86_64-linux` and `aarch64-darwin`. This publishes the fixed-output npm dependency tree and final package so downstream hosts in restricted npm environments can substitute from Cachix instead of contacting `registry.npmjs.org` during evaluation/build.

## Carried runtime patch: root cause and fix

### Observed failure

Runtime investigation on host `auto` found repeated bridge diagnostics of the form `tool_result_delivery_mismatch` with `expectedCount: 2`, `deliveredCount: 1`, `resolvedCount: 1`, and `waitingCount: 1`. Follow-up diagnostics reported `repair_tool_pairing_synthetic_results`, and the shared Claude session was marked `needsRebuild: true` / `forceRotate: true`. In user-visible sessions this correlated with the manual "keep going" symptom: a new user turn was often needed before productive continuation resumed.

Those observations are facts from the local auto-log investigation, not claims from upstream. The inferred root cause is narrower: during an active Claude query with parallel tool calls, Pi history could contain more than one `toolResult`, but the bridge's active-query callback delivered only the tail-extracted subset to the waiting Claude MCP handlers. One handler resolved, another remained pending, teardown saw `expectedCount > deliveredCount`, and the bridge correctly treated the Claude transcript as unsafe to resume.

### Why synthetic repairs and rebuild/rotation were symptoms, not the primary fix

Upstream bridge code already had defensive integrity checks. When it had to insert a placeholder for a missing pair, it logged `repair_tool_pairing_synthetic_results` ([upstream diagnostic code](https://github.com/vanillagreencom/vstack/blob/d70c86ff9302ddecb7e2ae9d833bacb0544d6ecd/pi-extensions/pi-claude-bridge/src/index.ts#L383-L404)). When query teardown or abort still had unresolved/waiting/queued/unmatched results, it logged `tool_result_delivery_mismatch`, marked the shared Claude session for rebuild, and could force rotation ([upstream mismatch code](https://github.com/vanillagreencom/vstack/blob/d70c86ff9302ddecb7e2ae9d833bacb0544d6ecd/pi-extensions/pi-claude-bridge/src/index.ts#L406-L443)).

Those mechanisms prevent silent corruption, but they do not deliver the missing active result to Claude Code. They happen after the bridge has already failed to resolve every pending MCP handler for the active query. Rebuild/rotation can keep later turns from reusing a corrupted Claude session, and synthetic results can keep transcript shape valid, but neither recovers the real missing tool output in the in-flight turn. That is why users could still see an apparent stall and need to type "keep going".

### Why the previous test-only patch was insufficient

A previous patch covered only conversion/history ordering: after an assistant message with multiple `toolCall` blocks, interleaved Pi user text is held until all corresponding `toolResult` blocks are placed adjacent to that assistant for Anthropic transcript validity ([conversion regression in the carried patch](./patches/fix-multi-tool-results.patch#L178-L211)). That test is still valuable because the Anthropic/Claude message format requires `tool_result` blocks to answer preceding `tool_use` blocks before unrelated user text.

However, conversion is not the same as active-query delivery. The live bridge also has per-tool pending handlers waiting for results while Claude Code is blocked in MCP tool calls. If `extractAllToolResults(context)` returned only one tail result, the conversion test could pass while the active handler for a second tool call still never received its result. The observed mismatch (`expectedCount: 2`, `deliveredCount: 1`, `waitingCount: 1`) is specifically an active-delivery failure, so a test-only conversion patch did not touch the failing runtime path.

### What this runtime patch changes

The carried patch wires the active-query result path in `src/index.ts` through a new helper, `deliverToolResults()` ([patch import and call site](./patches/fix-multi-tool-results.patch#L4-L50)). Instead of trusting only the tail extraction, the helper:

1. records which ids were extracted from the active tail, which `toolResult` ids exist in full Pi message history, and which recorded tool calls still have waiting handlers ([diagnostic structure](./patches/fix-multi-tool-results.patch#L68-L81));
2. scans the full Pi context for `role: "toolResult"` messages and converts their content to MCP results ([context scan](./patches/fix-multi-tool-results.patch#L94-L105));
3. computes `presentButNotExtractedIds` and `missingFromContextIds` so the logs distinguish "Pi has the result but tail extraction missed it" from "Pi never recorded the result" ([diagnosis](./patches/fix-multi-tool-results.patch#L107-L127));
4. supplements delivery with context results whose `toolCallId` matches a recorded Claude tool call and is not already represented in the extracted set ([supplement path](./patches/fix-multi-tool-results.patch#L129-L147));
5. refuses unknown result ids exactly as before, so a result for an unregistered tool call cannot be misdelivered to another pending handler ([unknown-id guard](./patches/fix-multi-tool-results.patch#L149-L157));
6. skips already resolved duplicates instead of re-queuing them and creating simultaneous pending/queued state ([duplicate guard](./patches/fix-multi-tool-results.patch#L158-L162));
7. resolves each pending handler, marks delivered/resolved progress, or queues known early results using the existing query context maps ([delivery loop](./patches/fix-multi-tool-results.patch#L163-L176)).

The intended runtime effect is that the likely failure mode identified by the investigation can complete in the active turn: if Pi history contains both tool results for a two-tool assistant turn, but tail extraction saw only one, `deliverToolResults()` supplements the missing known result from history and resolves both pending handlers. The new patched source file is `src/tool-result-delivery.ts` (visible in [`patches/fix-multi-tool-results.patch`](./patches/fix-multi-tool-results.patch#L51-L177)). True missing results remain visible: `missingFromContextIds` stays non-empty, teardown mismatch behavior remains in place, and the bridge still rebuilds/rotates rather than pretending success.

### Tests carried with the patch

The patch adds two kinds of regression coverage and the Nix build runs both ([check command list](./nix/pi-claude-bridge.nix#L36-L43)):

- A conversion test proves interleaved Pi user text is replayed after grouped parallel tool results, preserving Anthropic history ordering ([test patch](./patches/fix-multi-tool-results.patch#L185-L207)).
- Active delivery tests prove a waiting result present in Pi history but absent from tail extraction is supplemented and resolved, duplicate resolved results are skipped, and unknown ids are rejected ([test file patch](./patches/fix-multi-tool-results.patch#L212-L260)).

## Proven facts vs remaining risks

Proven by repository files and validation:

- The flake pins upstream source/version/hashes in [`VERSION.json`](./VERSION.json#L1-L8).
- The package builds from source with Node 22, applies the runtime patch, runs typecheck and focused tests, and validates Pi extension metadata ([package derivation](./nix/pi-claude-bridge.nix#L14-L63)).
- The patch changes active-query delivery, not just conversion tests ([active call site](./patches/fix-multi-tool-results.patch#L12-L50), [`tool-result-delivery` helper](./patches/fix-multi-tool-results.patch#L51-L177)).
- Downstream `tools` can consume the package as a local Pi package path from `bridge.passthru.packagePath` ([tools integration branch](https://github.com/rrvsh/tools/blob/pi-claude-bridge-nix-integration/nix/modules/claude-code.nix#L6-L15)).

Remaining runtime-validation risks:

- The exact `auto` failure shape was inferred from diagnostics and local tests; a live long-running Pi/Claude Code reproduction after rebuild is still the strongest validation.
- The helper scans full current Pi context for recorded ids. It refuses unknown ids and skips already resolved duplicates, but a future Pi history-shape change could require adjusting the context scan.
- Upstream updates may move or rewrite the active-query delivery code, so `nix run .#update` must be followed by a build and review of patch applicability.

## Validation commands

For this repository:

```sh
nix flake show --all-systems
nix build --print-build-logs .#pi-claude-bridge
git diff --check
```

For downstream `tools` after bumping the input:

```sh
cd /home/rafiq/1_repos/tools
nix flake lock --update-input pi-claude-bridge
nix develop -c just check-nix
nix eval .#darwinConfigurations.auto.config.home-manager.users.binmohm.programs.pi-coding-agent.settings.packages
```

Do not run a system rebuild from this repository. Rebuilds belong in the affected `tools` checkout/host workflow.
