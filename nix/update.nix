{
  perSystem =
    { pkgs, config, ... }:
    {
      packages.update = pkgs.writeShellApplication {
        name = "update-pi-claude-bridge";

        runtimeInputs = [
          pkgs.coreutils
          pkgs.curl
          pkgs.git
          pkgs.gnutar
          pkgs.gzip
          pkgs.jq
          pkgs.nix
          pkgs.nodejs_22
          pkgs.prefetch-npm-deps
        ];

        text = ''
          metadata=$(curl -fsSL https://registry.npmjs.org/@vanillagreen%2fpi-claude-bridge/latest)
          version=$(printf '%s' "$metadata" | jq -r .version)
          rev=$(printf '%s' "$metadata" | jq -r .gitHead)
          if [ -z "$rev" ] || [ "$rev" = "null" ]; then
            echo "npm metadata did not include gitHead for @vanillagreen/pi-claude-bridge@$version" >&2
            exit 1
          fi

          archive_url="https://github.com/vanillagreencom/vstack/archive/$rev.tar.gz"
          src_hash=$(nix store prefetch-file --json --unpack "$archive_url" | jq -r .hash)

          workdir=$(mktemp -d)
          trap 'rm -rf "$workdir"' EXIT
          curl -fsSL "$archive_url" | tar -xz -C "$workdir"
          src_dir="$workdir/vstack-$rev/pi-extensions/pi-claude-bridge"
          npm_hash=$(prefetch-npm-deps "$src_dir/package-lock.json")

          jq -n \
            --arg version "$version" \
            --arg rev "$rev" \
            --arg srcHash "$src_hash" \
            --arg npmDepsHash "$npm_hash" \
            --arg sourceRoot "pi-extensions/pi-claude-bridge" \
            --arg lockfileSource "upstream subdirectory package-lock.json" \
            '{version: $version, rev: $rev, srcHash: $srcHash, npmDepsHash: $npmDepsHash, sourceRoot: $sourceRoot, lockfileSource: $lockfileSource}' > VERSION.json

          nix flake update
        '';
      };

      apps.update = {
        type = "app";
        program = "${config.packages.update}/bin/update-pi-claude-bridge";
      };
    };
}
