# Luna Goes Places

This repository contains the runnable Godot source for Luna Goes Places.

## Build

Install Godot 4.7.1 with matching export templates, then copy
`local.paths.ps1.example` to `local.paths.ps1` and set `LunaGodotBin`. From the
repository root, run:

```powershell
.\build.ps1
```

The script exports every configured preset into `builds/<version>/`.

## License and notices

The game is distributed under [LICENSE.md](LICENSE.md). Runtime third-party
assets and required notices are listed in [THIRD_PARTY_ASSETS.md](THIRD_PARTY_ASSETS.md)
and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Play and download

The version currently recommended for play is available from the project's public
landing page. Its browser build, APK, Windows ZIP, source, and notices all point to
the same versioned GitHub Release. The Windows ZIP contains a runnable
`luna-goes-places.exe` with embedded game data and the required notices. The
landing-page source lives in [site/](site/); generated release artifacts are not
committed here.
