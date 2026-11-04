# IPv6 Mesh

A computer networks course project that builds an IPv6 mesh network (OpenThread over IEEE 802.15.4) on nRF52840 boards.

## Flashing a board

The board flashes over USB with `.uf2` files.

1. Short **RST to GND twice quickly**. A USB drive named `NICENANO` appears.
2. Copy the `.uf2` file onto the drive.
3. The board reboots into the new firmware on its own, and the drive disappears.

To open the board's shell (USB serial):

```sh
picocom /dev/ttyACM0        # quit: Ctrl-A, Ctrl-X
```

Your user must be in the `dialout` group. Messages printed before you open the port are lost.

## Building and flashing open thread node example

`ot-node/` is our copy of the nRF Connect SDK OpenThread CLI sample.
Run these commands in the nRF Connect SDK v3.4.2 toolchain environment:

```sh
cd ~/ncs/v3.4.2
west build -p always -b promicro_nrf52840/nrf52840/uf2 \
  -d ~/code/networks/mesh-ipv6/build/ot-node ~/code/networks/mesh-ipv6/ot-node
```

Put the board in bootloader mode (double-tap RST), then flash:

```sh
cp ~/code/networks/mesh-ipv6/build/ot-node/ot-node/zephyr/zephyr.uf2 /run/media/$USER/NICENANO/
```

Flash the same image to every board.

## Setting up the network

### Create a new network (first node)

```
ot dataset init new
ot dataset commit active
ot ifconfig up
ot thread start
ot state                  # after a few seconds: leader
ot dataset active -x      # copy this hex for the other nodes
```

### Add a node

```
ot dataset set active <hex from the first node>
ot ifconfig up
ot thread start
ot state                  # child, then router
ot ping <ML-EID of another node>
```

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
| `fdxx:…:0:ff:fe00:XXXX` | RLOC | Routing address. Changes when the mesh layout changes |
| `fdxx:…:<random>` | ML-EID | Stable address of the node. **Use this one for pings and apps** |
| `fe80::…` | Link-local | Reaches neighbors one radio hop away only |
