{
  description = "Zane's Nix configuration";

  nixConfig = {
    extra-substituters = [
      "https://cache.numtide.com"
      "https://vicinae.cachix.org"
    ];
    extra-trusted-public-keys = [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "vicinae.cachix.org-1:1kDrfienkGHPYbkpNj1mWTr7Fm1+zcenzgTizIcI3oc="
    ];
  };

  # 这里定义整个系统/用户配置所依赖的外部 flake。
  inputs = {
    # Stable nixpkgs：作为系统和 home-manager 的主 pkgs
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11?shallow=1";

    # Unstable nixpkgs：用于个别需要新版本的软件
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable?shallow=1";

    # Flake output composition and input partitions.
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    # Home Manager：用户态配置，必须与主 nixpkgs 保持一致
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Rust toolchain 管理（比 nixpkgs 自带的更新）
    fenix = {
      url = "github:nix-community/fenix?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Affinity 软件（依赖 unstable）
    affinity = {
      url = "github:mrshmllow/affinity-nix?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # LLM agents / AI tooling（作为工具使用）
    llm-agents.url = "github:numtide/llm-agents.nix";

    # Official Vicinae package and Home Manager module, including macOS launchd support.
    vicinae.url = "git+https://github.com/vicinaehq/vicinae?rev=8c63ae2ef1d46592b2236ec077575280f718d659";

    # sops-nix：用于管理 secrets（系统模块型工具）
    sops-nix = {
      url = "github:Mic92/sops-nix?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # 这是 flake 的入口（main）：
  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "aarch64-darwin"
        "x86_64-linux"
      ];

      imports = [
        ./flakes
      ];
    };
}
