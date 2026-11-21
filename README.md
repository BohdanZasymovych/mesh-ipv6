# IPv6 Mesh

A computer networks course project that builds an IPv6 mesh network (OpenThread over IEEE 802.15.4) on nRF52840 boards (nice!nano / `promicro_nrf52840`).

A laptop with one board acts as a Thread Border Router, connects the mesh to the normal network and switches an IKEA GRILLPLATS Matter plug on and off over IPv6: **[docs/border-router.md](docs/border-router.md)**.

## Repository layout

```
ot-node/        firmware for mesh nodes: OpenThread CLI over USB (copy of the NCS cli sample)
ot-rcp/         firmware for the Border Router radio (copy of the NCS coprocessor sample)
compose.yaml    OpenThread Border Router in Docker, uses an ot-rcp board
scripts/        build, flash, Border Router and Matter plug helpers
docs/           border-router.md: laptop as Border Router + IKEA Matter plug
.env.example    per-machine settings, copy to .env
```

Each firmware folder is a copy of the Nordic sample plus our files in `boards/promicro_nrf52840_nrf52840_uf2.*`.

## Requirements

- Linux (tested on Pop!_OS 24.04, which is based on Ubuntu 24.04)
- [nRF Connect SDK](https://docs.nordicsemi.com/bundle/ncs-latest/page/nrf/installation.html) **v3.4.2**, installed with nRF Connect for VS Code or `nrfutil sdk-manager`. The scripts expect it in `~/ncs/v3.4.2`; set `NCS_DIR` in `.env` if it is somewhere else
- Your user in the `dialout` group (`uucp` on Arch) for serial access
- For the Border Router: see [docs/border-router.md](docs/border-router.md)

Check a laptop with `scripts/doctor.sh`. It lists what is missing and how to fix it.

## Building and flashing

Open a terminal in the NCS v3.4.2 toolchain environment (so that `west` works), then from the repo root:

```bash
scripts/build.sh ot-node      # or ot-rcp
scripts/flash.sh ot-node      # then double-tap RST to GND when asked
```

`flash.sh` waits for the `NICENANO` USB drive, copies `zephyr.uf2` to it and the board reboots into the new firmware. It finds the drive wherever the distro mounts it (`/media/$USER` on Ubuntu, `/run/media/$USER` on Fedora and Arch).

Flash `ot-node` to every mesh board. Flash `ot-rcp` to one board only, the Border Router radio.

<details>
<summary>Without the scripts</summary>

```bash
cd ~/ncs/v3.4.2
west build -p always -b promicro_nrf52840/nrf52840/uf2 -d <repo>/build/ot-node <repo>/ot-node
```

Short RST to GND twice quickly, a `NICENANO` drive appears. Copy `<repo>/build/ot-node/ot-node/zephyr/zephyr.uf2` onto it.
</details>

## Opening the board shell

The `ot-node` shell runs over USB serial. Open it with `picocom` or any other serial terminal:

```bash
ls -l /dev/serial/by-id/        # stable names, one per board
picocom /dev/ttyACM0            # or the /dev/serial/by-id/... path
```

*Use Ctrl-A, Ctrl-X to quit. Messages printed before you open the port are lost.*

The `ot-rcp` board has no shell. Do not open it with picocom while the Border Router is running.

## Setting up the network

### Create a new network (first node)

```
ot dataset init new
ot dataset commit active
ot ifconfig up
ot thread start
ot state
ot dataset active -x
```

*After a few seconds `ot state` shows `leader`. `ot dataset active -x` prints the network settings (the active dataset) as a hex string. Copy it to add other nodes to the network*

If the Border Router is running, skip this: its network already exists, and its dataset is in `thread.dataset` (see [docs/border-router.md](docs/border-router.md#add-ot-node-boards-to-the-network)).

### Add a node

```
ot dataset set active <hex from the first node or thread.dataset>
ot ifconfig up
ot thread start
ot state
ot ping <ML-EID of another node>
```

*`ot state` shows `child` first and `router` later. Get the ML-EID of a node with `ot ipaddr` (see [Reading `ot ipaddr`](#reading-ot-ipaddr))*

The network settings are saved in flash. After a reboot, run `ot ifconfig up` and `ot thread start` again.

## Main commands

All OpenThread commands start with `ot`. Press Tab to complete commands.

| Command | What it does |
|---|---|
| `ot state` | Role of this node: `disabled`, `detached`, `child`, `router` or `leader` |
| `ot ipaddr` | IPv6 addresses of this node |
| `ot ping <addr>` | Ping another node |
| `ot dataset active -x` | Print the network settings as hex (for joining) |
| `ot neighbor table` | Nodes within one radio hop |
| `ot router table` | Routers in the mesh |
| `ot rloc16` | Short 16-bit address of this node in the mesh |
| `ot factoryreset` | Erase the network settings and reboot |

### Reading `ot ipaddr`

| Address pattern | Name | Use |
|---|---|---|
| `fdxx:…:0:ff:fe00:fc00` | Leader ALOC | Anycast address of the current leader (only on the leader) |
| `fdxx:…:0:ff:fe00:XXXX` | RLOC | Routing address (`XXXX` = `ot rloc16`). Changes when the mesh layout changes |
| `fdxx:…:<random>` | ML-EID | Stable address of the node. **Use this one for pings and apps** |
| `fe80::…` | Link-local | Reaches neighbors one radio hop away only |

## Border Router and Matter plug

A laptop with one `ot-rcp` board becomes a Thread Border Router that connects the mesh to the normal network and controls an IKEA GRILLPLATS Matter plug over IPv6. Setup, scripts and troubleshooting: [docs/border-router.md](docs/border-router.md).
