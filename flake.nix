{
  description = "Development environment for Limusic";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in {
      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          linuxPackages = with pkgs; nixpkgs.lib.optionals stdenv.hostPlatform.isLinux [
            gtk3
            libayatana-appindicator
            dbus
            mpv
            librsvg
            openssl
            pkg-config
            webkitgtk_4_1
          ];
        in {
          default = pkgs.mkShell {
            packages = with pkgs; [
              cargo
              nodejs
              pnpm
              rustc
              rustfmt
              (cargo-tauri.overrideAttrs (_: {
                doCheck = false;
              }))
            ] ++ linuxPackages;

            shellHook = ''
              export RUST_SRC_PATH="${pkgs.rustPlatform.rustLibSrc}"
              ${pkgs.lib.optionalString pkgs.stdenv.isLinux ''
              export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath linuxPackages}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
              ''}
            '';
          };
        });
    };
}
