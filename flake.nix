{
  description = "A Nix flake for creating an R development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};

      packages = with pkgs; [
        R
        radianWrapper
      ];

      rPackages = with pkgs.rPackages; [
        devtools
        filelock
        keyring
        languageserver
        openai
        pkgdown
        qtkit
        reprex
        skimr
        sodium
        tidyverse
        tinytex
        usethis
      ];

      texlivePackages = with pkgs.texlive; [
        (combine {
          inherit scheme-small;
          # Add additional texlive packages here if needed
        })
      ];

      allPackages = packages ++ rPackages ++ texlivePackages;
    in {
      devShell = pkgs.mkShell {
        buildInputs = allPackages;
        shellHook = ''
          export R_LIBS_USER=$PWD/Library
          mkdir -p "$R_LIBS_USER";
        '';
      };
    });
}
