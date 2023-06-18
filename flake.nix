{
  description = "latex-tools";
  inputs =
    {
      nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
      flake-utils.url = "github:numtide/flake-utils";
    };
  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        # texlive = pkgs.texlive.combined.scheme-full;
        texlive = pkgs.texlive.combined.scheme-small;
        docker = {
          image = {
            name = "latex-tools";
            tag = "dev";
          };
        };
        set-environment = pkgs.writeShellScript "set-env.sh" ''
          export PROJECTPATH="''${PROJECTPATH:-$(${pkgs.git}/bin/git rev-parse --show-toplevel)}"

          # shellcheck source=/dev/null
          source "''${PROJECTPATH}"/settings.env
        '';
      in
      {
        packages = {

          document-compiler = pkgs.writeShellApplication {
            name = "document-compiler";
            runtimeInputs = [ texlive pkgs.coreutils ];
            text = ''
              # shellcheck source=/dev/null
              source ${set-environment}

              pushd "''${PROJECTPATH}"
              mkdir -p "''${OUTDIR}"
              popd

              pushd "''${PROJECTPATH}"/"''${SRCDIR}"

              pdflatex \
                -output-directory="''${PROJECTPATH}"/"''${OUTDIR}" \
                -jobname="''${JOBNAME}" \
                "''${TEXFILE}"


              popd
            '';
          };

          file-watcher = pkgs.writeShellApplication {
            name = "file-watcher";
            runtimeInputs = [
              self.packages.${system}.document-compiler
              pkgs.findutils
              pkgs.entr
            ];
            text = ''
              # shellcheck source=/dev/null
              source ${set-environment}
              pushd "''${PROJECTPATH}"/"''${SRCDIR}"

              find . -name "*.tex" | entr document-compiler

              popd
            '';
          };

          docker-image = pkgs.dockerTools.buildLayeredImage {
            name = docker.image.name;
            tag = docker.image.tag;
            contents = [
              pkgs.bash
              self.packages.${system}.file-watcher
            ];
            config = {
              Cmd = [ "file-watcher" ];
              WorkingDir = "/data";
              Volumes = {
                "/data" = { };
              };
              Env = [
                "PROJECTPATH=/data"
              ];
            };
          };
        };
        apps = {
          default = self.apps.${system}.document-compile;
          file-watch = flake-utils.lib.mkApp { drv = self.packages.${system}.file-watcher; };
          document-compile = flake-utils.lib.mkApp { drv = self.packages.${system}.document-compiler; };
          all = flake-utils.lib.mkApp {
            drv = pkgs.writers.writeBashBin "document-all"
              ''
                source ${set-environment}
                pushd ''${PROJECTPATH}

                #Run compiler once to make sure that the pdf exists.
                ${self.packages.${system}.document-compiler}/bin/document-compiler

                ${self.packages.${system}.file-watcher}/bin/file-watcher &
                file-watcher-pid=$!

                ${pkgs.zathura}/bin/zathura ''${PROJECTPATH}/''${OUTDIR}/''${JOBNAME}.pdf &
                zathura-pid=$!

                trap "pkill -P $$" SIGINT

                wait

                popd
              '';
          };
        };
        devShells = {
          default = pkgs.mkShell {
            nativeBuildInputs =
              (with pkgs; [
                zathura
                entr
              ]) ++ [
                texlive
              ];
          };
        };
      });
}
