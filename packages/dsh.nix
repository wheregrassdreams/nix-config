{ inputs }:
final: _prev:
{
  # Upstream packaging patches dsh to use `--expose-internals` instead of the
  # native require-builtin addon, so it works with the Nix-built Node. Its
  # aarch64-darwin build is published to cache.numtide.com.
  dsh = inputs.llm-agents.packages.${final.stdenv.hostPlatform.system}.dsh;
}
