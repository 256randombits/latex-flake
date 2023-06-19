# LaTeX-flake

Tools and template for working with LaTeX.

## Usage

### Start new document
```
cd new-document
git init
nix flake init -t github:256randombits/latex-flake
git add -A
git commit -m "Initial commit"
nix run .#all
```
