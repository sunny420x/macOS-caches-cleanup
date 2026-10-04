# macOS Cache Cleaner

This interactive script helps reclaim storage by removing selected, regenerable caches from your Mac. It previews available locations and their approximate sizes before asking you to choose what to clean.

It can check user app caches, common browser caches, Xcode and Simulator caches, Adobe media caches, and selected developer package caches. The list is limited to known cache directories; it does not clean system-wide locations.

## Use

```sh
chmod +x run.sh
./run.sh
```

Choose cache locations by number, separated by spaces or commas, or enter `all`. Nothing is deleted until you type `CLEAN` at the final confirmation prompt. Enter `q` at the selection prompt to cancel.

Preview the locations and estimated sizes without deleting anything:

```sh
./run.sh --dry-run
```

## Safety notes

- Run as your normal macOS user. The script refuses to run as root; do not use `sudo`.
- Quit the related applications before cleaning. Apps can recreate cache files while running.
- Removing browser caches can sign you out of some sites or make pages load more slowly the next time.
- Only the contents of listed cache directories are removed. Personal data directories such as Simulator device data, Android virtual devices, downloads, and project files are not included.
- Space recovered is measured from the filesystem before and after cleanup, so it is approximate and may differ from the preview.
