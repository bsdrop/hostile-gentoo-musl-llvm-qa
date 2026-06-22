# 05 · Wayland and PipeWire — no X11, no PulseAudio, seatd instead of elogind

How the display and audio stack was installed while keeping X11 and PulseAudio out. The elogind
blocker is summarized here; full detail is in [07-exceptions.md](07-exceptions.md) (E14/E15).

## Installed

`media-video/pipewire`, `media-video/wireplumber`, `dev-libs/wayland`, `dev-libs/wayland-protocols`,
`sys-auth/seatd`, `media-libs/mesa`, `sys-apps/dbus`, and the `selinux-wayland` and `selinux-seatd`
policy modules. All built on musl/clang/LTO. `dbus` and `seatd` run as OpenRC services.

## No X11

`mesa` is built with `USE="-X wayland vaapi vulkan"`, and no `x11-base/xorg-server` is installed.
`VIDEO_CARDS="virtio virgl"` targets QEMU's virtio-gpu. The one indirect problem: under
`FEATURES=test`, GUI library test dependencies pull `xorg-server` and `mesa[X]` (see
[04-selinux.md](04-selinux.md), E11). This stack is therefore installed with command-scoped
`FEATURES=-test`; global `test` stays on.

## No PulseAudio

`pipewire` is built with `-pulseaudio`, and no `media-sound/pulseaudio` is installed. PipeWire is the
audio server. The `sound-server` and `pipewire-alsa` USE flags can be enabled to make it the active
ALSA backend; they were left off for the minimal install.

## seatd instead of elogind

The target USE includes `elogind`, but `elogind-257.16` does not compile on musl (E14):
`src/libelogind/sd-journal/journal-file.h` references an incomplete `struct stat`. musl needs an
explicit `<sys/stat.h>`, which glibc pulls in transitively, and clang treats the result as an error.
elogind on musl is a known-hard port.

The seat and session manager used instead is standalone `seatd` (`sys-auth/seatd` with `server`,
`-elogind`). `-elogind` is set on `pipewire`, `wireplumber`, `seatd`, `polkit`, and `dbus`, and seatd
runs as the seat daemon. `elogind` stays in global USE; it is disabled only where it would otherwise
be pulled into a build that cannot succeed.

## Compositors and desktops

On the hardened full-LTO base, with XWayland off (`-X`):

- Hyprland (via the third-party `hyproverlay` overlay) and wlroots-based sway both build and run on
  musl/clang/LTO.
- GNOME and KDE do not build on musl because they require logind (elogind or systemd), which is not
  available here (E14, and findings F9). This is recorded as a blocker, and is the reason for the
  second image on glibc.

Results are tracked in [08-findings.md](08-findings.md).
