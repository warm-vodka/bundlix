{ requirements, ... }:
{
  requires = requirements;
  system.events = [ "editor" ];
  home.events = [ "editor" ];
}
