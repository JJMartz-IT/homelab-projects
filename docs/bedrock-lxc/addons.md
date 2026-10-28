# ImportedWorld and add-ons

[Back to the project](README.md)

## Imported world

The active world is ImportedWorld:

```properties
level-name=ImportedWorld
```

Its folder is /srv/bedrock/worlds/ImportedWorld. Importing the world
initially resulted in an unexpected player inventory/location. This
record does not establish a universal fix for player identity data.

The world originally referenced Marketplace packs. Missing-pack warnings
must be checked against the world's actual dependencies; do not delete
references just to suppress warnings.

## Add-ons used in the project

| Add-on | Requested file | Recorded progress |
| --- | --- | --- |
| Bedrock Essentials+ | [8837761](https://www.curseforge.com/minecraft-bedrock/addons/bedrock-essentials/download/8837761) | Installation reported working; later restored with other packs |
| OTG Backpack | [8555196](https://www.curseforge.com/minecraft-bedrock/addons/otg-backpack/download/8555196) | Behavior pack appeared in startup pack stack |
| Fabulous Furnished / Fabulous Furniture | [8968428](https://www.curseforge.com/minecraft-bedrock/addons/fabulous-furnished/download/8968428) | Behavior pack appeared in startup pack stack |
| Inventory Organizer | [7479241](https://www.curseforge.com/minecraft-bedrock/texture-packs/inventory-organizer/download/7479241) | Resource-pack installation was guided; individual UI behavior was not separately confirmed |

The October 28 server update was reported working. That does not replace
a feature-by-feature compatibility test of every add-on.

## Pack layout and registration

Behavior packs provide gameplay behavior; resource packs provide client
assets and UI. Bedrock add-ons are not Java mod-loader JAR files.

Relevant paths:

- /srv/bedrock/behavior_packs/
- /srv/bedrock/resource_packs/
- /srv/bedrock/worlds/ImportedWorld/world_behavior_packs.json
- /srv/bedrock/worlds/ImportedWorld/world_resource_packs.json

The world JSON files already contained multiple entries. Preserve those
entries and add or update the intended pack, rather than replacing the
entire list with one new entry.

Each world entry must use the pack header UUID and version from that
specific pack's manifest. Do not use a module UUID or copy identifiers
from an unrelated release. Dependencies and required experiment/API
versions must also be satisfied.

## Installation checklist

1. Obtain the selected Bedrock add-on from its author/distribution page.
   Keep the original archive and record the release.
2. Pause scheduled backups, wait for any active job, stop the server and
   take a verified backup before changing world/pack files.
3. Inspect the archive in a separate staging directory. An mcaddon may
   contain multiple nested mcpack archives.
4. Locate each pack root containing manifest.json. Check its header,
   modules, dependencies and engine requirements.
5. Place behavior and resource pack roots in the corresponding server
   directories without introducing an extra directory layer.
6. Merge the corresponding header UUID/version registrations into the
   world's existing JSON lists. Preserve unrelated packs and their order.
7. Restore bedrock:bedrock ownership and readable permissions.
8. Start the server, inspect pack/script errors, join and test the new
   feature. Resume backups after verification.

Do not blindly parse every manifest as strict JSON: Inventory Organizer's
manifest was encountered with comments and a string version. Inspect the
actual format and supported version instead of assuming all manifests
have the same shape.

## Recovery and compatibility notes

- The shutdown-related terrain incident occurred while add-ons were in
  use, but the evidence did not establish that an add-on caused it.
- Keep the matching pack files and world registrations with each backup.
- Inventory Organizer changes client UI; check its behavior alongside
  other UI-changing packs such as OTG Backpack.
- The server update process retained custom packs. Retaining files does
  not prove compatibility with every later engine release.
- Do not distribute purchased Marketplace content or third-party pack
  archives in this public repository.

See [recovery](backup-recovery.md) and [updates](updates.md).
