# Hardy Firmware History

`hardy` is an ASUS Chromebook Flip C436F / Google Helios converted from ChromeOS
to MrChromebox coreboot firmware on 2025-12-01. The installed method was
MrChromebox's full-ROM option because RW_LEGACY was blocked.

The original ChromeOS firmware backup is retained in the dedicated
[chromebook-asus-flip-C436](https://github.com/daneroo/chromebook-asus-flip-C436)
repository. That repository is the source for the conversion record, backup
artifact, and photographs; do not duplicate the ROM image here.

When firmware write protection was removed by disconnecting the battery, the
original USB-C power adapter was required to keep the machine stable. Treat a 45
W USB-C PD supply as a prerequisite for repeating hardware work of that kind.

Current NixOS hardware observations, including the MrChromebox firmware version,
belong in [throttling.md](throttling.md).
