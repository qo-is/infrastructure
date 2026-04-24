# Code Style Guidlines

General:

- Always run `nix fmt` before commiting

## Nix

- Never use `with lib;` or `rec`
- Use `let inherit (lib) fn1 fn2; in` instead of `lib.fn1`, `lib.fn2`
- Use `let inherit (pkgs) pkg1 pkg2; in` instead of `pkgs.pkg1`, `pkgs.pkg2`
- For nested sets (e.g. `lib.types`), inherit from the nested set: `inherit (lib.types) str int`
- Merge all inherits into a single `let...in` block alongside any other `let` bindings
- Use `pipe` from `lib` to reduce complex nested statements, where it makes sense, it works like this:\\
  ```nix
  pipe 2 [
    (x: x + 2)  # 2 + 2 = 4
    (x: x * 2)  # 4 * 2 = 8
  ]
  ```
