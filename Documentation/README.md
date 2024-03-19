Documentation
====================

This subdirectory contains the documentation for the VMP project.
A guide for both deployment and development is provided which features a
comprehensive overview of the VMP project.

The documentation is written in Markdown and is build using *pandoc*.

## Building the Documentation

Make sure you have `pandoc`, `xelatex`, and `make` installed on your system.
When running NixOS, open a ephemeral shell with `nix-shell -p texlive.combined.scheme-full pandoc gnumake`.

Then, run the following command in this directory:
```bash
make
```