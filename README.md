# Pony Island ticket checker

[![License][badge-1-img]][badge-1-link]

## About

This is a simple CLI that checks your [Pony Island][1] (the game) data to see
the tickets (in-game concept) you are missing. The idea here is to automate the
steps on [this guide][2].

This program works for both Linux (native and Proton) and Windows. macOS and UWP
aren't supported due to lack of interest of mine. Let me know if you want
something like that.

All data is read-only. This software does not change any saved data.

### Building

Currently, `zig build` doesn't work. You need to run either `./build linux` or
`./build windows`. Binaries will be in `zig-out/bin/`.

### Testing

Run `zig test src/main.zig`.

### Usage

After building, just run `./zig-out/bin/pony-island-ticket-checker`. Add
`--help` for more info.

Windows version should also just work with a double-click on the .exe file.

## Source code

The main repository is on [SourceHut][source-srht]. Mirrors exist on
[Codeberg][source-codeberg] and [GitHub][source-github] for convenience, but
they might occasionally be outdated.

## License and contribution

All original code is licensed under the
[GNU Affero General Public License 3.0 or later][license-code].

Unless you explicitly state otherwise, any contribution intentionally submitted
for inclusion in the work by you shall be licensed under the same license as
the material to which it is contributed, without any additional terms or
conditions.

[1]: https://store.steampowered.com/app/405640/Pony_Island
[2]: https://steamcommunity.com/sharedfiles/filedetails?id=3837647268

[badge-1-img]: https://img.shields.io/badge/license-AGPL--3.0--or--later-green?style=flat-square
[badge-1-link]: ./LICENSE

[source-srht]: https://git.sr.ht/~paemuri/pony-island-ticket-checker
[source-codeberg]: https://codeberg.org/paemuri/pony-island-ticket-checker
[source-github]: https://github.com/paemuri/pony-island-ticket-checker

[license-code]: ./LICENSES/AGPL-3.0-or-later.txt
