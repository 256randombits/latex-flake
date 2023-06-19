{
  description = "A LaTeX Document";
  inputs =
    {
      latex-flake.url = "github:256randombits/latex-flake";
      flake-utils.url = "github:numtide/flake-utils";
    };
  outputs = { latex-flake, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem
      (system:
        {
          apps = {
            file-watch = latex-flake.apps.${system}.file-watch;
            all = latex-flake.apps.${system}.all;
          };
        });
}
