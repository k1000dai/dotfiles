#!/bin/bash

#update the flake
nix flake update nixpkgs
# update the home-manager configuration
home-manager switch --flake .
