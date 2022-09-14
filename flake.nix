{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    crane = {
      url = "github:ipetkov/crane";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dfinity-sdk = {
      url = "github:paulyoung/nixpkgs-dfinity-sdk?rev=28bb54dc1912cd723dc15f427b67c5309cfe851e";
      flake = false;
    };

    flake-utils.url = "github:numtide/flake-utils";

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
  };

  outputs = { self, nixpkgs, crane, dfinity-sdk, flake-utils, rust-overlay, ... }:
    let
      supportedSystems = [
        flake-utils.lib.system.aarch64-darwin
        # flake-utils.lib.system.x86_64-darwin
      ];
    in
      flake-utils.lib.eachSystem supportedSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              (final: prev: (import dfinity-sdk) final prev)
              (import rust-overlay)
            ];
          };

          # icfs uses #[feature] which can only be used on the nightly release channel.
          rustWithWasmTarget = pkgs.rust-bin.nightly."2022-06-01".default.override {
            targets = [ "wasm32-unknown-unknown" ];
          };

          # NB: we don't need to overlay our custom toolchain for the *entire*
          # pkgs (which would require rebuidling anything else which uses rust).
          # Instead, we just want to update the scope that crane will use by appending
          # our specific toolchain there.
          craneLib = (crane.mkLib pkgs).overrideToolchain rustWithWasmTarget;

          dfinitySdk = (pkgs.dfinity-sdk {
            acceptLicenseAgreement = true;
            sdkSystem = system;
          }).makeVersion {
            systems = {
              "x86_64-darwin" = {
                sha256 = "sha256-nLocFGJ5pI1KG7ZdWjFpWwd7ZP+Ed4TjfBLLSKkq2/o=";
              };
            };
            version = "0.12.0-beta.1";
          };

          buildRustPackage = options: craneLib.buildPackage ({
            TARGET_CC = "${pkgs.stdenv.cc.nativePrefix}cc";
            src = ./.;
            # crane tries to run the Wasm file as if it were a binary
            doCheck = false;
          } // options);

          ic-sqlite = buildRustPackage {
            cargoExtraArgs = "--package ic-sqlite";
          };

          ic-sqlite-example = buildRustPackage {
            cargoExtraArgs = "--package ic-sqlite-example";
          };
        in
        {
          checks = {
            inherit ic-sqlite ic-sqlite-example;
          };

          packages = {
            inherit ic-sqlite ic-sqlite-example;
          };

          defaultPackage = ic-sqlite-example;

          devShell = pkgs.mkShell {
            RUST_SRC_PATH = pkgs.rustPlatform.rustLibSrc;
            TARGET_CC = "${pkgs.stdenv.cc.nativePrefix}cc";

            inputsFrom = builtins.attrValues self.checks;

            nativeBuildInputs = with pkgs; [
              dfinitySdk
              rustWithWasmTarget
            ];
          };
        });
}
