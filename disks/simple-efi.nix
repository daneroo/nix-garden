# { disks ? [ "/dev/sda" ], ... }:
{
  # from https://github.com/nix-community/disko/blob/master/example/simple-efi.nix
  disko.devices = {
    disk = {
      vdb = {
        device = "/dev/sda";
        # device = builtins.elemAt disks 0;
        # device = "/dev/disk/by-id/some-disk-id";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              type = "EF00";
              size = "500M";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };
}
