{
  description = "EPIVÍOSI NEWS — rédaction chiffrée pour journalistes en zone de conflit, pour EPIVÍOSI OS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs =
    { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      modeles = pkgs.callPackage ./templates { };
    in
    {
      # Implémente `epiviosi.news.enable` (option déclarée par le socle EPIVÍOSI OS).
      nixosModules.default = import ./module.nix;

      packages.${system} = {
        epiviosi-news-modeles = modeles;
        epiviosi-news = pkgs.callPackage ./pkgs/epiviosi-news { inherit modeles; };
        default = self.packages.${system}.epiviosi-news;
      };

      checks.${system} = {
        inherit (self.packages.${system}) epiviosi-news-modeles epiviosi-news;
        vm = import ./tests/news.nix {
          inherit pkgs;
          module = self.nixosModules.default;
        };
      };
    };
}
