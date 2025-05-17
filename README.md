## Build the ISO image

```bash
nix build -L .#nixosConfigurations.installer.config.system.build.isoImage
ls -l ./result/iso
````

## Run QEMU with the ISO image

```bash
nix run -L .
````
