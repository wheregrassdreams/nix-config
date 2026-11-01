{ ... }:
final: prev: {
  disktree =
    if final.stdenv.hostPlatform.isDarwin then
      final.stdenvNoCC.mkDerivation {
        pname = "disktree";
        version = "0.11.0";

        src =
          let
            archive =
              if final.stdenv.hostPlatform.isAarch64 then
                {
                  arch = "aarch64";
                  hash = "sha256-lC8lCPu71pAfeWSUSSsWJQ1SInFVsKtZ9qWkRrAzYAs=";
                }
              else
                {
                  arch = "x86_64";
                  hash = "sha256-Ft26bD2YNlHLY4nRx/1qBwukQ6r88DwryFfjXnO0P00=";
                };
          in
          final.fetchurl {
            url = "https://github.com/tobi/disktree/releases/download/v0.11.0/disktree-0.11.0-${archive.arch}-macos.zip";
            inherit (archive) hash;
          };

        nativeBuildInputs = [ final.unzip ];
        dontBuild = true;

        installPhase = ''
          runHook preInstall
          mkdir -p "$out/Applications" "$out/bin"
          unzip -q "$src" -d "$out/Applications"
          ln -s "$out/Applications/disktree.app/Contents/MacOS/disktree" "$out/bin/disktree"
          runHook postInstall
        '';

        meta = {
          description = "Disk usage treemap for finding and removing files";
          homepage = "https://github.com/tobi/disktree";
          license = final.lib.licenses.mit;
          platforms = [
            "aarch64-darwin"
            "x86_64-darwin"
          ];
          mainProgram = "disktree";
        };
      }
    else
      prev.disktree;
}
