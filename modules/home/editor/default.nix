{config, ...}:{
  home.file.".config/nvim".source = config.lib.file.mkOutOfStoreSymlink ../../../resources/nvim;
}
