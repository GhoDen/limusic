{
  description = "Development environment for Limusic";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in {
      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          linuxPackages = with pkgs; nixpkgs.lib.optionals stdenv.hostPlatform.isLinux [
            gtk3
            libayatana-appindicator
            mpv
            librsvg
            openssl
            pkg-config
            glib-networking
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
              cargo-tauri
            ] ++ linuxPackages;

            shellHook = ''
              export RUST_SRC_PATH="${pkgs.rustPlatform.rustLibSrc}"
              export GIO_MODULE_DIR="${pkgs.glib-networking}/lib/gio/modules"
              export GIO_EXTRA_MODULES="${pkgs.glib-networking}/lib/gio/modules"
              ${pkgs.lib.optionalString pkgs.stdenv.isLinux ''
              export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath linuxPackages}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
              ''}
            '';
          };
        });

      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        nixpkgs.lib.optionalAttrs (system == "x86_64-linux") {
          default = let
            # rusty_v8 otherwise downloads this archive from its Cargo build script.
            v8Archive = pkgs.fetchurl {
              url = "https://github.com/denoland/rusty_v8/releases/download/v130.0.7/librusty_v8_release_x86_64-unknown-linux-gnu.a.gz";
              hash = "sha256-pkdsuU6bAkcIHEZUJOt5PXdzK424CEgTLXjLtQ80t10=";
            };
            desktopFile = pkgs.writeText "limusic.desktop" ''
              [Desktop Entry]
              Type=Application
              Name=Limusic
              Comment=Desktop YouTube Music client
              Exec=limusic
              Icon=limusic
              Terminal=false
              Categories=AudioVideo;Audio;Player;
              StartupWMClass=limusic
            '';
          in
          pkgs.rustPlatform.buildRustPackage {
            pname = "limusic";
            version = "0.8.0";
            src = ./.;
            doCheck = false;

            cargoDeps = pkgs.rustPlatform.importCargoLock {
              lockFile = ./Cargo.lock;
            };

            pnpmDeps = pkgs.fetchPnpmDeps {
              pname = "limusic-ui";
              version = "0.8.0";
              src = ./ui;
              pnpm = pkgs.pnpm;
              fetcherVersion = 4;
              hash = "sha256-uDdLf6rQryD/fDU4nHa9rjXu8GxYQkdfpu0KZMbi8IQ=";
            };
            pnpmRoot = "ui";

            nativeBuildInputs = with pkgs; [
              pkg-config
              nodejs
              pnpm
              pnpmConfigHook
              rustPlatform.cargoSetupHook
              cargo
              rustc
              makeWrapper
            ];

            buildInputs = with pkgs; [
              mpv
              webkitgtk_4_1
              librsvg
              openssl
              gtk3
              glib
              glib-networking
              libayatana-appindicator
            ];

            preBuild = ''
              (cd ui && node node_modules/vite/bin/vite.js build)
            '';

            buildPhase = ''
              runHook preBuild
              cargo build --release --offline -p limusic-app
            '';

            installPhase = ''
              install -Dm755 target/release/limusic-app $out/bin/limusic
              wrapProgram $out/bin/limusic \
                --set GIO_MODULE_DIR "${pkgs.glib-networking}/lib/gio/modules" \
                --set GIO_EXTRA_MODULES "${pkgs.glib-networking}/lib/gio/modules"
              install -Dm644 src-tauri/icons/128x128.png \
                $out/share/icons/hicolor/128x128/apps/limusic.png
              install -Dm644 ${desktopFile} \
                $out/share/applications/limusic.desktop
            '';

            env = {
              RUSTY_V8_ARCHIVE = v8Archive;
            };
          };
        });
    };
}
