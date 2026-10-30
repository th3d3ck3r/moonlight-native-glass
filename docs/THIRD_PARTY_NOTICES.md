# MoonlightLG credits, licenses, and source

MoonlightLG's native interface and modifications are maintained by Th3D3ck3r.
The streaming engine is derived from Moonlight Qt and moonlight-common-c by the
Moonlight developers and contributors. These credits do not replace or remove
any original author's copyright.

MoonlightLG is free software under GNU GPL version 3. Recipients may redistribute
and modify it under those terms. It is provided without any warranty, including
merchantability or fitness for a particular purpose. The full license is in
the repository's `LICENSE` file and included with every release package.

## In the app

**About MoonlightLG → Licenses & Notices** opens an offline notice index bundled
with the streaming helper. It contains the full GPL, original third-party
license/copyright files, Qt's third-party attribution metadata, and the original
ModeSeven font notice. The app menu also provides **Licenses & Notices** directly.

The inventory includes Qt, SDL/SDL compatibility/SDL_ttf, FreeType, HarfBuzz,
FFmpeg/dav1d, Opus, OpenSSL, libplacebo, Discord RPC, MoltenVK and its pinned
dependencies, shader toolchain sources, qmdnsengine, ENet, nanors, h264bitstream,
and the SDL controller database. Original texts are retained rather than replaced
with a generic list of license names. Source/build inventories may include code
that is not linked into every package.

Qt libraries are dynamically linked. Their LGPL/GPL notices and third-party
license texts are included. MoonlightLG imposes no additional restriction on
modifying/relinking those libraries or reverse engineering for debugging such
modifications. Recipients can build and ad-hoc sign their own modified version.

## Corresponding source

Each full release attaches `MoonlightLG-VERSION-source.tar.gz` alongside its app
downloads and checksums. It includes the tracked application and initialized
submodule sources, plus the dependency source archives used for notice collection.
`third-party-source/SOURCES.json` records exact refs, upstream URLs and archive
hashes. The dependency recipe archive includes the macOS patches and build scripts.

The app's **Corresponding Source** link points to that same release asset.
The source tag and public repository provide an additional way to obtain the
application and inspect its history.

## Packaging checks

Both command-line and Xcode builds collect notices before signing the helper.
Bundle validation fails if the offline index, full GPL, notices, source inventory,
font attribution, or a required component's original license files are missing.
Release publication verifies successful builds and source/package checksums before
uploading the exact validated archives.
