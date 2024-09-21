# disko-format-install script

[disko](https://github.com/nix-community/disko) is a declarative disk partitioning tool for NixOS.

With flakes, disk-config is discovered first under the `.diskoConfigurations` top level attribute
or else from the disko module of a NixOS configuration of that name under `.nixosConfigurations`.

We will use the second option.

And we will select the nixos configuration from the FLAKEURI to use for the disk configuration.
