{
  description = "DE for your nix-on-droid install";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  };

  outputs = { self, nixpkgs }:
    let
      forEachSystem = nixpkgs.lib.genAttrs [ "aarch64-linux" "x86_64-linux" ];
    in
    {
      apps = forEachSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        id_c = pkgs.writeText "id.c" ''
          #include <sys/types.h>
          #include <stdio.h>

          int setgid(gid_t gid){ printf("WARNING: setgid stubbed"); return 0; }
          int setuid(uid_t uid){ printf("WARNING: setuid stubbed"); return 0; }
        '';

        id_so = pkgs.runCommand "id.so" { buildInputs = [ pkgs.gcc ]; } ''
          mkdir -p $out
          gcc -std=c99 -shared -fPIC ${id_c} -o $out/id.so
        '';

        novnc-overriden = pkgs.novnc.overrideAttrs {
          version = "1.5.0-beta";
          src = pkgs.fetchFromGitHub {
            owner = "novnc";
            repo = "noVNC";
            rev = "v1.5.0-beta";
            sha256 = "sha256-xZZCUCeJOKKjP5nJ7Hk7oRF6inFZrapIwfugJP+UBDg=";
          };
        };

        myx = pkgs.writeShellScriptBin "myx" ''
          export DISPLAY=:1
          LD_PRELOAD=${id_so}/id.so ${pkgs.xorg.xorgserver}/bin/Xvfb :1 -ac -nolisten unix -listen tcp &
          sleep 5
          #exec env PATH="''${PATH:+''${PATH}:}${pkgs.dbus}/bin" ${pkgs.dbus}/bin/dbus-run-session --config-file=${pkgs.dbus}/share/dbus-1/session.conf ${pkgs.awesome}/bin/awesome &
          exec env DISPLAY=:1 PATH="''${PATH:+''${PATH}:}${pkgs.dbus}/bin:${pkgs.lib.getBin pkgs.plasma5Packages.kwin}/bin:${pkgs.lib.getBin pkgs.plasma5Packages.plasma-workspace}/bin:${pkgs.lib.getBin pkgs.plasma5Packages.plasma-desktop}/bin:${pkgs.lib.getBin pkgs.plasma5Packages.kinit}/libexec/kf5" ${pkgs.dbus}/bin/dbus-run-session --config-file=${pkgs.dbus}/share/dbus-1/session.conf ${pkgs.plasma5Packages.plasma-workspace}/bin/startplasma-x11 &
          ${pkgs.rxvt-unicode}/bin/urxvt -e env TERM=xterm ${pkgs.tmux}/bin/tmux &
          sleep 3
          ${pkgs.x11vnc}/bin/x11vnc -display :1 -passwd test -rfbport 5902 -noshm -forever &
          PATH="''${PATH:+''${PATH}:}${pkgs.busybox}/bin" ${novnc-overriden}/bin/novnc --vnc localhost:5902 --listen localhost:6081 &
        '';

        myx-wrapped = pkgs.writeShellScriptBin "myx-wrapped" ''
          ${pkgs.proot}/bin/proot -b ${pkgs.lib.getBin pkgs.plasma5Packages.kinit}/libexec/kf5/start_kdeinit:/run/wrappers/bin/start_kdeinit ${myx}/bin/myx
        '';
      in
      {
        default = self.apps.${system}.x11;

        x11 = {
          type = "app";
          program = "${myx-wrapped}/bin/myx-wrapped";
        };
      });
    };
}
