# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/all-hardware.nix")
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.initrd.systemd.enable = true;

  networking.hostName = "nixos"; # Define your hostname.
  networking.hostId = "c939dc2e"; # cut -c-8 </proc/sys/kernel/random/uuid
  networking.useNetworkd = true;

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Automatically log in at the virtual consoles.
  services.getty.autologinUser = "root";

  # Allow the user to log in as root without a password.
  users.users.root.initialHashedPassword = "";

  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.05"; # Did you read the comment?
}
