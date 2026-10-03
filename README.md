# BOMBKI - Pascal byte-perfect reconstruction.

This is a byte-perfect reconstruction of the original 1999' BOMBKI
text mode RPG. Provided with FPC and TP7 build scripts and pipelines.

This is based on extensive work done as part of collaboration on
https://github.com/rzuf79/bombki , with an explicit approval from the game's
original author, Mateusz Pawluczuk.

tl;dr question:
>(...) uwaga, jest prosba o blogoslawienstwo \[projektu rekonstrukcyjnego\]!(...)

tl;dr answer:
>(...) Blogoslawienstwo (...) dane! (...) Pozdrawiam, Mateusz

## Setup

- Bash & Python 3 for scripts.
- Free Pascal (FPC) for a host-native build and tests.
- For genuine TP7 builds, a Turbo Pascal 7 installation and DOSBox-X. Set
  `TP7_ROOT` to the TP7 directory if it is not in a standard location.
- DOSEMU2 is an optional DOS runtime. The following options disable KVM
  (to run in WSL2) and change the CPU emu to avoid Pascal CRT RE 200:

  ```ini
  $_cpu_vm = "emulated"
  $_cpu_vm_dpmi = "emulated"
  $_cpuemu = (1)
  ```

  Note that `-dumb` doesn't really work for Pascal because CRT writes to video
  memory directly, so no DOS/BIOS terminal access happens. Use `-t` instead.

DOSEMU2 is sufficient to play and test; DOSBox-X is best for 100% accuracy.

## Common commands

Build the native Linux executable:

```sh
python3 tools/build_fpc.py --target linux
```

Compile with genuine TP7 in DOSBox-X, without starting the game:

```sh
python3 tools/build_tp7_dosbox.py --no-run
```

Run the TP7 executable in DOSEMU2's terminal frontend without opening a window:

```sh
dosemu -q -t \
  -I '$_cpu_vm = "emulated"' \
  -I '$_cpu_vm_dpmi = "emulated"' \
  -I '$_cpuemu = (1)' \
  -I '$_external_char_set = "utf8"' \
  -I '$_internal_char_set = "cp437"' \
  -K "$PWD/build/tp7" -E BOMBKI.EXE
```

(you might also place the above into your DOSEMU2 settings file of choice).
