{ config, pkgs, lib, modulesPath, targetSystem, ... }:
let
  installer = pkgs.writeShellApplication {
    name = "installer";
    runtimeInputs = with pkgs; [
      dosfstools
      e2fsprogs
      gawk
      nixos-install-tools
      util-linux
      config.nix.package
    ];
    text = ''
      set -euo pipefail

      echo "Setting up disks..."
      for i in $(lsblk -pln -o NAME,TYPE | grep disk | awk '{ print $1 }'); do
        if [[ "$i" == "/dev/fd0" ]]; then
          echo "$i is a floppy, skipping..."
          continue
        fi
        if grep -ql "^$i" <(mount); then
          echo "$i is in use, skipping..."
        else
          DEVICE_MAIN="$i"
          break
        fi
      done
      if [[ -z "$DEVICE_MAIN" ]]; then
        echo "ERROR: No usable disk found on this machine!"
        exit 1
      else
        echo "Found $DEVICE_MAIN, erasing..."
      fi

      DISKO_DEVICE_MAIN=''${DEVICE_MAIN#"/dev/"} ${targetSystem.config.system.build.diskoScript} 2> /dev/null

      echo "Installing the system..."

      export PATH=${lib.makeBinPath [
              # hack for a progress bar
        # https://nix.dev/manual/nix/2.18/command-ref/nix-build#opt-log-format
        (pkgs.writeShellScriptBin "nix-env" ''
          exec ${lib.getExe' config.nix.package "nix-env"} --log-format bar "$@"
        '')
      ]}:$PATH

      nixos-install --no-channel-copy --no-root-password --option substituters "" --system ${targetSystem.config.system.build.toplevel}

      echo "Done! Rebooting..."
      sleep 3
      reboot
    '';
  };
  installerFailsafe = pkgs.writeShellScript "failsafe" ''
    ${lib.getExe installer} || echo "ERROR: Installation failure!"
    sleep 3600
  '';
in
{
  imports = [
    (modulesPath + "/installer/cd-dvd/iso-image.nix")
    (modulesPath + "/profiles/all-hardware.nix")
  ];

  boot.kernelParams = [ "systemd.unit=getty.target" ];
  boot.supportedFilesystems.zfs = true;

  networking.hostId = "67faa5a0";

  isoImage.isoName = "${config.isoImage.isoBaseName}-${config.system.nixos.label}-${pkgs.stdenv.hostPlatform.system}.iso";
  isoImage.makeEfiBootable = true;
  isoImage.makeUsbBootable = true;
  isoImage.squashfsCompression = "zstd -Xcompression-level 15"; # xz takes forever

  systemd.services."getty@tty1" = {
    overrideStrategy = "asDropin";
    serviceConfig = {
      ExecStart = [ "" installerFailsafe ];
      Restart = "no";
      StandardInput = "null";
    };
  };

  system.stateVersion = lib.mkDefault lib.trivial.release;
}
