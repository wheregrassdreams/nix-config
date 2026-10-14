{ inputs }:
final: _prev: {
  # Use llm-agents' own package set, built and updated against rolling nixpkgs.
  # Applications opt in individually through their packageChannel option.
  latestAgents = inputs.llm-agents.packages.${final.stdenv.hostPlatform.system};
}
