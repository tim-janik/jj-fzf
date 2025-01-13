{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs = inputs:
    let forEachSystem = inputs.nixpkgs.lib.genAttrs inputs.nixpkgs.lib.systems.flakeExposed;
    in {
      packages = forEachSystem (system:
        let pkgs = import inputs.nixpkgs { inherit system; };
            jj-fzf = pkgs.writeShellApplication {
              name = "jj-fzf";
              runtimeInputs = with pkgs; [ jujutsu fzf gawk gnused ];
              text = ''
                ${./jj-fzf} "$@"
              '';
            };
        in {
          inherit jj-fzf;
          default = jj-fzf;
        }
      );
    };
}
