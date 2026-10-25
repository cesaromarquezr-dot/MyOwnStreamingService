# Disc Ingestion Center: MakeMKV, optical drive, and NAS workflow

This guide describes the new desktop-first Disc Ingestion Center in MyOwnStreamingService.
It is intended for media you own or are otherwise authorized to copy. Copyright and anti-circumvention rules vary by jurisdiction; check the laws and licenses that apply to you.

## What the app now does

- Saves the path to an installed MakeMKV console executable and a destination root on the local machine.
- Discovers optical drives through MakeMKV's documented robot/CLI mode.
- Starts one user-confirmed rip job at a time, writing into a unique subfolder below the selected output root.
- Tracks process status, phase text, percentage from MakeMKV's current progress values, recent console events, exit code, and generated `.mkv` paths.
- Stores up to 100 job records and at most 120 recent event lines per job in local app preferences. Jobs marked running after an app restart are changed to interrupted/failed instead of being reported as live.
- Validates a completed MKV's file accessibility and EBML/Matroska header signature, then asks the user to review title, year, disc format, optional edition label, and optional poster URL before adding a metadata entry to the app's local catalog.

### Important validation limitation

The signature check is only a basic container-header check. It is not a complete read-through, checksum, or playback test. Use a media-server scan or an optional tool such as FFmpeg/`ffprobe` to perform a deeper stream/format check before relying on a large rip. The app does not embed `ffprobe` or claim a file is playable just because its header is valid.

A catalog record created by this flow does **not** store a raw Windows/NAS path in `playbackUrl`. To play the file, the media server must scan the same output folder and expose an authorized playback URL through the existing server/gateway architecture.

## Install and prepare

1. Download MakeMKV from the [official MakeMKV download page](https://www.makemkv.com/download/). The official page listed version 2.0.0 on 20 September 2026 when this guide was prepared; check that page for current releases and integrity information.
2. Install it and open the desktop GUI once so you can confirm that the optical drive is visible and inspect its reported model, firmware revision, and LibreDrive status.
3. Connect the optical drive directly to the computer that runs the Flutter desktop app. A slim internal SATA optical drive needs a compatible SATA-to-USB adapter or enclosure and sufficient power. A USB-C conversion adapter only changes the connector and does not guarantee that the drive receives adequate power or works through every enclosure.
4. Create or mount the destination folder. A mapped path such as `Y:\Movies` works only in a Windows session that can see that mapping. When running elevated apps, mapped drives can be invisible across UAC contexts; a NAS UNC path such as `\\nas-name\media\Movies` may be more reliable when permitted by your setup.
5. Open **Physical Media → Disc Ingestion Center** or the entry in **Innovation & Platform Hub**. Set the MakeMKV console path (commonly `C:\Program Files (x86)\MakeMKV\makemkvcon64.exe`) and output root; save settings and test write access.
6. Insert a disc, detect drives, select the intended drive, confirm that you are authorized to make the copy, and start a job.
7. By default, the title selector is `all`, matching MakeMKV's documented example and allowing multiple titles/extras. If you enter a numeric title index, confirm that index in MakeMKV first. Review the completed output files; do not assume every title on a disc is the main feature.
8. Import each desired MKV separately. Review the metadata fields and provide a poster URL only from a source you are allowed to use. For TV discs, episodes, bonus content, commentaries, and soundtrack material, select an appropriate type and avoid labeling extras as a feature film.
9. Configure your media server to scan the same destination, and verify playback through its authorized stream/gateway path. The local catalog import is not itself a media-server scanner.

## MakeMKV CLI used by the app

MakeMKV's official developer page links to `usage.txt`, which documents automation mode, line-based messages and progress values. Relevant examples from that documentation are:

```text
makemkvcon -r --cache=1 info disc:9999
makemkvcon mkv disc:0 all c:\folder
```

The app uses the equivalent argument-list invocation with `--robot`, a 128 MB cache, the discovered drive index, the selected title selector and the unique output directory. It does not build a shell command string; process arguments are passed separately. Only one local MakeMKV process is started by this screen at a time.

MakeMKV's download page currently states that administrator privileges are required on Windows for the beta version due to its Windows SCSI API limitation. If local launch or drive access fails, confirm the actual version, installation, permissions, and drive connectivity. The app does not auto-elevate itself.

## LG BU40N and firmware caution

LG's product specifications identify the BU40N's host interface as SATA. An external USB connection therefore depends on an appropriate adapter/enclosure. Confirm the exact drive model and the information shown by MakeMKV; do not infer UHD/LibreDrive compatibility from the product name alone.

**Availability check (24 October 2026):** LG's official product page marks the BU40N as discontinued. Some third-party listings remain indexed, but the listings checked showed backorder or out-of-stock states, so the transcript's claim that it is easy to buy is not reliably true everywhere. Stock and seller condition can change; verify the exact model and return policy before purchasing.

The video transcript mentions flashing a BU40N firmware variant. That is **not automated or bundled** by this project. Firmware suitability can differ with current firmware revision, hardware/production variant, platform, and enclosure/bridge behavior. A MakeMKV forum discussion from 5 October 2026 illustrates that a BU40N reported with firmware FR07 was treated differently from a drive already running a patched 1.03 revision; this is a reason to check the actual drive report rather than copy a firmware choice from the video. A wrong flash can leave a drive unusable and may affect warranty or legal/regulatory obligations. Before considering firmware changes, review the current [MakeMKV UHD drive guide](https://forum.makemkv.com/forum/viewtopic.php?f=16&t=19634) and [SDFtool Flasher community thread](https://forum.makemkv.com/forum/viewtopic.php?f=16&t=22896), verify your exact drive details, and don't proceed on the basis of a video alone. No firmware binaries are included in the project ZIP.

## Troubleshooting

- **No drive found:** Open MakeMKV GUI; verify the drive is detected, close apps that may hold it open, check power/cables, then rerun drive discovery.
- **MakeMKV executable not found:** Set the exact full path to `makemkvcon64.exe` (Windows) or `makemkvcon` (macOS/Linux). Do not point the field at the GUI executable if the console executable is installed separately.
- **Access denied:** Verify Windows permissions and MakeMKV's documented admin requirement. If elevating the app, recheck that the NAS path remains mounted in that elevated session.
- **Network output unavailable:** Test write permissions, free space and share availability before starting a long rip. Use a unique folder for each job to avoid collisions.
- **Exit code zero but no output:** Check the selected drive/title, MakeMKV messages and the folder that the job recorded.
- **MKV header failed:** Recreate or re-copy the file; don't import it as verified. A passing header is not a substitute for a complete integrity/playback check.
- **Playback missing after catalog import:** This flow adds metadata to the app library and deliberately doesn't set `playbackUrl` to a filesystem path. Configure the supported media server/gateway to index the file and return a stream URL.

## Official/source references

- MakeMKV download and release history: <https://www.makemkv.com/download/>
- MakeMKV developer automation page: <https://www.makemkv.com/developers/>
- MakeMKV CLI usage file: <https://www.makemkv.com/developers/usage.txt>
- LG BU40N product specifications: <https://www.lg.com/us/burners-drives/lg-bu40n-ultra-slim-blu-ray-external-dvd-drive>
- Current community UHD drive guide: <https://forum.makemkv.com/forum/viewtopic.php?f=16&t=19634>
- SDFtool Flasher discussion: <https://forum.makemkv.com/forum/viewtopic.php?f=16&t=22896>
