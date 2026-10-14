{
  # One bundle can configure both the system and the user's home. The wrapper
  # generates features.programs.git.enable and gates both parts together.
  nixos.programs.git.enable = true;
  home-manager.programs.git.enable = true;
}
