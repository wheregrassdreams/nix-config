{
  config,
  pkgs,
  ...
}:
let
  sopsAgeKeyFile = "${config.xdg.configHome}/sops/age/keys.txt";
  sshPrivateKeyFile = "${config.home.homeDirectory}/.ssh/id_ed25519";
in
{
  config = {
    my.paths.secrets = {
      inherit sopsAgeKeyFile;
      inherit sshPrivateKeyFile;
    };

    home.packages = with pkgs; [
      sops
      age
      ssh-to-age
    ];

    sops.age = {
      keyFile = sopsAgeKeyFile;
      sshKeyPaths = [ sshPrivateKeyFile ];
    };

    sops.defaultSopsFile = ../../../../secrets/common.yaml;

    home.sessionVariables = {
      SOPS_AGE_KEY_FILE = sopsAgeKeyFile;
      SOPS_AGE_SSH_PRIVATE_KEY_FILE = sshPrivateKeyFile;
    };
  };
}
