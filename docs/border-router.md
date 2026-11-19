# Border Router and IKEA GRILLPLATS plug

How to turn a laptop plus one nRF52840 board into a Thread Border Router and switch an IKEA GRILLPLATS Matter plug on and off over IPv6.

```
Laptop (Linux)                                   Thread mesh (802.15.4)
  chip-tool  ── IPv6/UDP ──┐                      ┌── GRILLPLATS plug (Matter, router)
  otbr-agent ── wpan0 ─────┴── USB ── nRF52840 RCP ~~ radio ~~┤
  (Docker)                                        └── nRF52840 CLI nodes (ot-node)
```

- **RCP board** (`ot-rcp/`) is only a radio. The whole Thread stack runs in `otbr-agent` on the laptop.
- **wpan0** is a virtual network interface created by `otbr-agent`. Packets sent to it go over USB to the RCP and out over the radio.
- **chip-tool** is the Matter controller. It sends encrypted Matter commands to the plug's IPv6 address (UDP port 5540).

## What you need

- Linux laptop with Bluetooth (tested on Pop!_OS 24.04, which is based on Ubuntu 24.04). macOS, Windows and WSL do not work: OTBR needs host networking and the USB serial port
- One nRF52840 board flashed with `ot-rcp`
- IKEA GRILLPLATS plug and its Matter QR code (on the plug or on the cover of the paper manual)

## One-time setup

### 1. Install the tools

Ubuntu / Pop!_OS:

```bash
sudo apt install -y bluez avahi-daemon avahi-utils picocom tcpdump wireshark curl snapd
# Docker: Docker CE from docs.docker.com, or the distro packages:
sudo apt install -y docker.io docker-compose-v2     # skip if Docker CE is installed
sudo usermod -aG docker,dialout,wireshark $USER     # then log out and back in
sudo snap install chip-tool
sudo snap connect chip-tool:bluez
sudo snap connect chip-tool:avahi-observe
sudo snap connect chip-tool:process-control
sudo systemctl disable --now ModemManager           # it grabs /dev/ttyACM* ports
```

`docker compose` (v2, with a space) is required, the old `docker-compose` (v1) is not enough.

### 2. Build and flash the RCP firmware

See [Building and flashing](../README.md#building-and-flashing) in the README:

```bash
scripts/build.sh ot-rcp
scripts/flash.sh ot-rcp
```

The board then shows up as `usb-Zephyr_Project_Thread_Co-Processor_<serial>-if00` in `/dev/serial/by-id/`.

### 3. Configure

```bash
cp .env.example .env
ls -l /dev/serial/by-id/     # copy the Thread_Co-Processor path into RCP_DEVICE
ip -br link                  # put the Wi-Fi or Ethernet interface name into INFRA_IF
scripts/doctor.sh            # checks everything above, prints what to fix
```

## Every session

```bash
scripts/host-setup.sh        # sysctl settings, needed again after every reboot
docker compose up -d         # start OTBR
scripts/thread-form.sh       # start the Thread network (creates it the first time)
scripts/status.sh            # check: state leader, wpan0 has fd... addresses
```

## Add ot-node boards to the network

`thread-form.sh` saves the network settings to `thread.dataset`. Give them to every `ot-node` board in its shell:

```bash
cat thread.dataset           # on the laptop
```

```
ot dataset set active <hex>
ot ifconfig up
ot thread start
```

The boards then appear in `scripts/status.sh` (router or child table) and can ping the laptop's `wpan0` addresses.

## A second Border Router (teammate's laptop)

Thread allows several Border Routers in one network. Send `thread.dataset` to the teammate over a private channel (it contains the network key). They put it in the repo root of their copy and run the [Every session](#every-session) steps: `thread-form.sh` sees the file and joins that network instead of creating a new one.

## Add the plug (once)

Plug it in (pairing mode lasts 15 minutes, the ON/OFF button restarts it) and run:

```bash
scripts/plug-pair.sh "MT:XXXXXXXXXXXXXXXXXXX"     # or the 11-digit code
```

The script downloads IKEA's Matter root certificate (PAA) for chip-tool, then commissions the plug: Bluetooth first, to give the plug the Thread network settings, then IPv6 over Thread for the rest. The full chip-tool output goes to `logs/pairing.log`.

## Control the plug

```bash
scripts/plug.sh on
scripts/plug.sh off
scripts/plug.sh toggle
scripts/plug.sh status
```

## Show that it is IPv6

```bash
scripts/status.sh                                   # plug appears in router table and SRP hosts
ping -6 -c3 <plug address from srp server host>
sudo tcpdump -i wpan0 -n 'ip6 and udp port 5540'    # then run scripts/plug.sh toggle
```

Add `-w toggle.pcapng` to tcpdump to open the capture in Wireshark. The payload is encrypted by Matter; the IPv6 and UDP headers are visible.

## Secrets: never commit these

| File | What it holds |
|---|---|
| `.env` | local paths (not secret, but machine-specific) |
| `thread.dataset`, `otbr-data/` | Thread network key |
| `logs/` | chip-tool output, `pairing.log` may include the network key |
| `~/snap/chip-tool/common/chip_tool_kvs` | Matter fabric keys. If lost, the plug must be factory reset and paired again |
| plug setup code (`MT:...`) | lets anyone nearby pair the plug while it is in pairing mode |

All of these are already in `.gitignore` or live outside the repo.

## Troubleshooting

Start with `scripts/doctor.sh`: it checks Docker, `.env`, the RCP port, chip-tool, Bluetooth and avahi.

| Symptom | Fix |
|---|---|
| `docker compose up` fails on `RCP_DEVICE` | `.env` missing or wrong path, check `ls -l /dev/serial/by-id/` |
| OTBR logs show RCP timeouts | port busy (picocom, ModemManager), or wrong board. `docker compose restart` |
| `thread-form.sh`: node did not attach | `docker compose logs otbr`, then `scripts/thread-form.sh` again |
| Pairing: `Failed Device Attestation` | PAA certificate missing, the script downloads it. Check `--paa-trust-store-path` |
| Pairing stops at Bluetooth | `bluetoothctl show` (Powered: yes), press the plug's ON/OFF button, move it closer |
| chip-tool cannot find the plug over the network | `systemctl status avahi-daemon`; if `ufw` is enabled, `sudo ufw allow 5353/udp` (mDNS) |
| `plug.sh` times out | `scripts/status.sh`: is the plug still in the router table? `ping -6` its address |
| `flash.sh` does not find NICENANO | double-tap RST again; if the drive shows up unmounted: `udisksctl mount -b /dev/disk/by-label/NICENANO` |
