# Meta harness catalog

Verified September 19, 2026. Meta harnesses are workspaces and terminals that host or coordinate coding agents. They appear in Discover by default and can be filtered independently of installation status. Accounts and underlying coding agents are configured in the respective tools.

| Tool | Install source | Metadata source |
| --- | --- | --- |
| Warp | Existing Homebrew definition | https://www.warp.dev/ |
| T3 Code | homebrew/cask/t3-code | https://github.com/Homebrew/homebrew-cask/blob/master/Casks/t/t3-code.rb |
| Conductor | homebrew/cask/conductor | https://github.com/Homebrew/homebrew-cask/blob/master/Casks/c/conductor.rb |
| Superset | homebrew/cask/superset | https://github.com/Homebrew/homebrew-cask/blob/master/Casks/s/superset.rb |
| Paseo | homebrew/cask/paseo | https://paseo.sh/download |
| cmux | manaflow-ai/cmux/cmux | https://github.com/manaflow-ai/homebrew-cmux/blob/main/Casks/cmux.rb |
| Orca (Stably) | stablyai/orca/orca | https://github.com/stablyai/homebrew-orca/blob/main/Casks/orca.rb |
| Herdr | herdr | https://herdr.dev/docs/install/ |
| Emdash | homebrew/cask/emdash | https://emdash.com/docs/installation |
| Antigravity | Existing Homebrew definition | https://antigravity.google/product/antigravity-2 |

Fully qualified cask names avoid collisions with unrelated formulae and include third-party taps where required. Installed app icons are loaded from local bundles; uninstalled tools without bundled artwork use initials. T3 Code detects both its normal and Alpha application names. Desktop bundle versions take precedence over embedded CLI versions. Homebrew installs use the existing prerequisite setup flow; manual installations use their own updaters.
