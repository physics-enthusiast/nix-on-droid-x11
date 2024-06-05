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

        myx = pkgs.writeShellScriptBin "myx" ''
          export DISPLAY=:1
          LD_PRELOAD=${id_so}/id.so ${pkgs.xorg.xorgserver}/bin/Xvfb :1 -ac -nolisten unix -listen tcp &
          sleep 5
          ${pkgs.x11vnc}/bin/x11vnc -display :1 -passwd test -rfbport 5902 -noshm -forever &
          ${pkgs.awesome}/bin/awesome &
          ${pkgs.rxvt-unicode}/bin/urxvt -e env TERM=xterm ${pkgs.tmux}/bin/tmux &
        '';
      in
      {
        default = self.apps.${system}.x11;

        x11 = {
          type = "app";
          program = "${myx}/bin/myx";
        };
      });
    };
}
