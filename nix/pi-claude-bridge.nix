{ lib, config, ... }:
let
  cfg = config.flake;
  inherit (cfg.paths) root;
  versionInfo = builtins.fromJSON (builtins.readFile (root + /VERSION.json));
in
{
  perSystem =
    { pkgs, ... }:
    let
      pname = "pi-claude-bridge";
      packageName = "@vanillagreen/pi-claude-bridge";
      packagePath = "lib/node_modules/${packageName}";
      bridge = pkgs.buildNpmPackage {
        inherit pname;
        version = versionInfo.version;

        src = pkgs.fetchFromGitHub {
          owner = "vanillagreencom";
          repo = "vstack";
          rev = versionInfo.rev;
          hash = versionInfo.srcHash;
        };

        sourceRoot = "source/${versionInfo.sourceRoot}";
        npmDepsHash = versionInfo.npmDepsHash;
        patches = [ ../patches/fix-multi-tool-results.patch ];
        nodejs = pkgs.nodejs_22;

        buildPhase = ''
          runHook preBuild
          npm run build
          runHook postBuild
        '';

        doCheck = true;
        checkPhase = ''
          runHook preCheck
          npm run typecheck
          node --import tsx --test tests/unit-import.mjs
          node --import tsx --test tests/unit-tool-result-delivery.mjs
          runHook postCheck
        '';

        doInstallCheck = true;
        nativeInstallCheckInputs = [ pkgs.nodejs_22 ];
        installCheckPhase = ''
          runHook preInstallCheck
          pkg="$out/${packagePath}"
          test -f "$pkg/package.json"
          test -f "$pkg/bundle/index.js"
          node - "$pkg/package.json" "${versionInfo.version}" <<'NODE'
          const fs = require("fs");
          const [manifestPath, expectedVersion] = process.argv.slice(2);
          const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
          if (manifest.name !== "@vanillagreen/pi-claude-bridge") throw new Error(`unexpected package name: ''${manifest.name}`);
          if (manifest.version !== expectedVersion) throw new Error(`unexpected version: ''${manifest.version}`);
          if (!Array.isArray(manifest.pi?.extensions) || !manifest.pi.extensions.includes("./bundle/index.js")) {
            throw new Error("missing Pi extension metadata for ./bundle/index.js");
          }
          NODE
          runHook postInstallCheck
        '';

        passthru.packagePath = "${placeholder "out"}/${packagePath}";

        meta = {
          description = "Pi provider bridge for Claude Code via Claude Agent SDK";
          homepage = "https://github.com/vanillagreencom/vstack/tree/main/pi-extensions/pi-claude-bridge";
          license = lib.licenses.mit;
          platforms = [
            "aarch64-darwin"
            "x86_64-linux"
          ];
        };
      };
      tarball = pkgs.runCommand "${pname}-${versionInfo.version}.tgz" { nativeBuildInputs = [ pkgs.gnutar ]; } ''
        mkdir package
        cp -R ${bridge}/${packagePath}/. package/
        tar --sort=name --owner=0 --group=0 --numeric-owner --mtime=@1 -czf "$out" package
      '';
      bridgeWithPassthru = bridge.overrideAttrs (old: {
        passthru = (old.passthru or { }) // {
          inherit tarball;
          packagePath = "${bridge}/${packagePath}";
        };
      });
    in
    {
      packages.pi-claude-bridge = bridgeWithPassthru;
      packages.default = bridgeWithPassthru;
    };
}
