# WiFi

Automating measurement taking for Throughput on IpadOS (iPad-Air-4) and Android (Pixel-6)

The stock iperf3 apps on android and ipados are not very good. So we just put together a simple script that runs iperf3 on the device and then reads the output. with [Ish](https://ish.app/) and [Temux](https://wiki.termux.com/wiki/Main_Page).

Here is an install script that should work on both devices.

```bash
# Install the tool
curl -sL bit.ly/miperf3-inst | sh

# Run speed test
./miperf3.sh
```

Let's push our installer script to a gist.

- bitly short url: <https://bit.ly/miperf3-inst>
- gist permanent url: <https://gist.githubusercontent.com/daneroo/f172382fe6027a20c4d910541f1ff708/raw/iperf3-mobile-install.sh>

Update the gist with the latest version of the script:

```bash
# This is how we push changes to the gist
gh gist edit f172382fe6027a20c4d910541f1ff708 --add ./iperf3-mobile-install.sh
```

This is how the gist was created:

```bash
# This is how we created the gist
gh gist create .//iperf3-mobile-install.sh --public --desc "iperf3 mobile testing script installer"
- Creating gist iperf3-mobile-install.sh
✓ Created public gist iperf3-mobile-install.sh
https://gist.github.com/daneroo/f172382fe6027a20c4d910541f1ff708
```

## AP Placement Measurements


| Spot ↓         | Signal | Up | Down | Signal  | Up | Down |
|----------------|--------|----|------|---------|----|------|
|                | Bell   |    |      | U6-Wall |    |      |
| Carport 1F     |        |    |      |         |    |      |
| Kitchen 1F     |        |    |      |         |    |      |
| Living 1F      |        |    |      |         |    |      |
| Office 1F      |        |    |      |         |    |      |
| Pool (outside) |        |    |      |         |    |      |
| TV (basement)  |        |    |      |         |    |      |
