{ pkgs ? import <nixpkgs> {} }:
  pkgs.mkShell {
    # nativeBuildInputs is usually what you want -- tools you need to run
    nativeBuildInputs = with pkgs.buildPackages; [ jdk17 ];

    NIXOS_OZONE_WL = "0";
    __GL_THREADED_OPTIMIZATIONS = "0";
}
