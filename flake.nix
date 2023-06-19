{
  description = "latex-tools";
  inputs =
    {
      nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
      flake-utils.url = "github:numtide/flake-utils";
    };
  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem
      (system:
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
              drv = pkgs.writeShellApplication {
                name = "document-all";
                runtimeInputs = [
                  self.packages.${system}.document-compiler
                  self.packages.${system}.file-watcher
                  pkgs.zathura
                ];
                text = ''
                  # shellcheck source=/dev/null
                  source ${set-environment}
                  pushd "''${PROJECTPATH}"

                  #Run compiler once to make sure that the pdf exists.
                  document-compiler

                  file-watcher &
                  # file_watcher_pid="$!"

                  zathura "''${PROJECTPATH}"/"''${OUTDIR}"/"''${JOBNAME}".pdf &
                  # zathura_pid=$!

                  trap 'pkill -P $$' SIGINT

                  wait

                  popd
                '';
              };
            };
            docker-import = flake-utils.lib.mkApp {
              drv = pkgs.writeShellApplication {
                name = "docker-import";
                runtimeInputs = [
                  pkgs.which
                ];
                text = ''
                  if ! which "docker" > /dev/null 2>&1
                  then
                    echo "Docker not found in PATH!"
                    exit 1
                  fi

                  docker load < ${self.packages.${system}.docker-image}
                '';
              };
            };
            docker-run = flake-utils.lib.mkApp {
              drv = pkgs.writeShellApplication {
                name = "docker-run";
                text = ''
                  # shellcheck source=/dev/null
                  source ${set-environment}

                  ${self.apps.${system}.docker-import.program}
                  docker run -it -v "''${PROJECTPATH}":/data ${docker.image.name}:${docker.image.tag}
                '';
              };
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
            editReadme = pkgs.mkShell {
              nativeBuildInputs = with pkgs;
                [
                  python311Packages.grip
                ];
            };

          };
        }) //
    {
      templates.default = {
        path = ./template;
        description = "A LaTeX document";
      };
    };
}
