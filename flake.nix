{
  description = "A Nix-flake-based Odin development environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
  };

  outputs = { self , nixpkgs ,... }: let
    system = "x86_64-linux";
  in {
    devShells."${system}".default = let
      pkgs = import nixpkgs {
        inherit system;
      };
    in pkgs.mkShell {
      packages = with pkgs; [
        git
        which
        clang_20
        llvmPackages_20.llvm
        llvmPackages_20.bintools
        openssl_3
      ];
    shellHook = "CXX=clang++";
    };
  };
}