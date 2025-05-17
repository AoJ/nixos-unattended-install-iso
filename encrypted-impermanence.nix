{ config, lib, ... }:
let
  zpoolName = "rpool";
in
{
  disko.devices = {
    disk = {
      main = {
        device = "/dev/$DISKO_DEVICE_MAIN";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            esp = {
              type = "EF00";
              size = "1G";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "defaults" ];
              };
            };
            root = {
              size = "100%";
              content = {
                type = "zfs";
                pool = zpoolName;
              };
            };
          };
        };
      };
    };
    zpool = {
      "${zpoolName}" = {
        type = "zpool";
        options = {
          ashift = "12";
        };
        rootFsOptions = {
          mountpoint = "none";
          acltype = "posixacl";
          xattr = "sa";
          atime = "off";
          compression = "off";
          encryption = "on";
          keyformat = "passphrase";
        };
        datasets = {
          "safe" = {
            type = "zfs_fs";
            options.mountpoint = "none";
          };
          "safe/persist" = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
            mountpoint = "/persist";
          };
          "local" = {
            type = "zfs_fs";
            options.mountpoint = "none";
            options.compression = "lz4";
          };
          "local/reserved" = {
            type = "zfs_fs";
            options.mountpoint = "none";
            options.refreservation = "2G";
          };
          "local/root" = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
            mountpoint = "/";
            postCreateHook = "zfs snapshot ${zpoolName}/local/root@blank";
          };
          "local/nix" = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
            mountpoint = "/nix";
          };
          "local/tmp" = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
            options.sync = "disabled";
            mountpoint = "/tmp";
          };
        };
      };
    };
  };

  boot.initrd.clevis.enable = true;
  boot.initrd.clevis.devices."${zpoolName}".secretFile = "/persist/etc/initrd/clevis/${zpoolName}.jwe";

  boot.initrd.systemd.services.initrd-rollback-root = {
    after = [ "zfs-import-${zpoolName}.service" ];
    before = [ "sysroot.mount" ];
    wantedBy = [ "initrd.target" ];
    description = "Rollback root filesystem to a pristine state on boot";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${config.boot.zfs.package}/sbin/zfs rollback -r ${zpoolName}/local/root@blank";
    };
    unitConfig.DefaultDependencies = "no";
  };

  boot.tmp.cleanOnBoot = true;

  fileSystems."/var/lib/nixos" = {
    device = "/persist/var/lib/nixos";
    options = [ "bind" "noauto" "x-systemd.automount" ];
  };

  fileSystems."/var/lib/systemd" = {
    device = "/persist/var/lib/systemd";
    options = [ "bind" "noauto" "x-systemd.automount" ];
  };

  services.openssh.hostKeys = lib.mkForce [
    {
      path = "/persist/etc/ssh/ssh_host_ed25519_key";
      type = "ed25519";
    }
  ];
}
