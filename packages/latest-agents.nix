{ inputs }:
final: _prev: {
  # Use llm-agents' own package set, built and updated against rolling nixpkgs.
  # AI packages select their implementation from this namespace directly.
  latestAgents = inputs.llm-agents.packages.${final.stdenv.hostPlatform.system};
}
