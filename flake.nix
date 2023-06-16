{
  description = "LaTeX bells and whistles";
  inputs =
    {
      nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
      flake-utils.url = "github:numtide/flake-utils";
    };
  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        texlive = pkgs.texlive.combined.scheme-full;
        set-environment = pkgs.writeShellScript ".sh" ''
          PROJECTPATH=$(${pkgs.git}/bin/git rev-parse --show-toplevel)
          source ''${PROJECTPATH}/settings.env
        '';
      in
      {
        packages = {

          document-compiler = pkgs.writers.writeBashBin "document-compiler" ''
            source ${set-environment}

            pushd ''${PROJECTPATH}
            ${pkgs.coreutils}/bin/mkdir -p ''${OUTDIR}
            popd

            pushd ''${PROJECTPATH}/''${SRCDIR}

            ${texlive}/bin/pdflatex \
              -output-directory=''${PROJECTPATH}/''${OUTDIR} \
              -jobname=''${JOBNAME} \
              ''${TEXFILE}


            popd
          '';

          file-watcher = pkgs.writers.writeBashBin "file-watcher" ''
            source ${set-environment}
            pushd ''${PROJECTPATH}/''${SRCDIR}

            ${pkgs.findutils}/bin/find . -name "*.tex" | entr ${self.packages.${system}.document-compiler}/bin/document-compiler

            popd
          '';
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

                trap "kill ''${file-watcher-pid} ''${zathura-pid}" SIGINT

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
