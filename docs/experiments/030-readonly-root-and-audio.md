# Read-only release root and upstream audio configuration

October 2, 2026. Replace first-boot system-file edits with supported configuration
so they survive a read-only root and are carried by the device tarball.

## Audio

The upstream sound guide explicitly supports
`PulseaudioModulesDroid_ExtraCardArgs` for HAL quirks:
https://docs.ubports.com/en/latest/porting/configure_test_fix/Sound.html
The implementation was merged before this port:
https://gitlab.com/ubports/development/core/ubuntu-touch-session/-/issues/30

The installed get_pa_modules_droid_extra_args generator supports CardArgs,
GlueArgs and HidlArgs. Its PulseAudio unit reads the generated environment file
at each startup. The overlay now supplies the measured legacy routing option
through ExtraCardArgs and `helper=false` through ExtraHidlArgs. The latter was
present on the working phone but missing from the previous release overlay.

On the phone, a runtime copy of touch.pa with only those two local arguments
removed was bind-mounted onto the original file. The runtime DeviceInfo YAML
supplied both arguments instead. PulseAudio restarted successfully and pactl
showed the droid card's legacy option and droid-hidl helper=false, with primary
and fast sinks and primary input present. This verifies argument propagation
and HAL initialization, not end-to-end call/media quality. Runtime files are in
/run/a50-audio-deviceinfo; reboot removes these test mounts. Roll back by
unmounting /etc/pulse/touch.pa, restoring before.yaml to the Wi-Fi runtime YAML,
and restarting the phablet PulseAudio user service. Restore audio first if also
rolling back the Wi-Fi experiment, because its saved YAML includes that overlay.

## Other removed first-boot mutations

- The datetime indicator dependency is a packaged relative systemd symlink.
- The sensorfwd unmask code repaired a past debugging artifact. The clean image
  has no sensorfwd mask, so it must not mutate unit files every boot.
- The loader-cache rewrite is unnecessary. With the app's bundled library path,
  the installed arm64 loader's --inhibit-cache --list resolves OpenStore's
  libxml2.so.2 and ICU 74 from the standard library directory. No cache write.

GNSS device-node permissions and user-session setup remain runtime operations.
No change to authentication or AppArmor policy is part of this cleanup.

## Release builder

Only --devel adds .writable_image. Non-development builds remove that marker,
including if supplied by an input tarball, and retain the normal read-only root.
Compatibility-library installation now fails the build on error instead of
printing a warning and shipping an image with known broken applications.

Linux shell syntax checks and the relative symlink target passed. An offline
rebuild against official 26.04 daily full image 376 is next. This still does not
validate rootfs-on-system boot, recovery hardware, OTA or fresh onboarding.
Suspend startup/restart integration is also still open; these independent
read-only-root changes do not claim to solve it.
