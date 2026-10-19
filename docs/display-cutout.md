# A50 display cutout

Uses the physical-pixel DeviceInfo keys documented by
[UBports](https://docs.ubports.com/en/latest/porting/configure_test_fix/device_info/DisplayCutouts.html),
in `overlay/system/etc/deviceinfo/devices/a50.yaml`.

Source: the device's `/android/vendor/overlay/framework-res__auto_generated_rro_vendor.apk`,
SHA256 `810f38b6c606a375c89e276acae2999b80cc2cfcb2661c775b1c26876fb31b34`.
Read with `aapt dump --values resources`.
The proprietary APK is not committed.

- Display: 1080 x 2340 pixels, verified by Mir.
- Vendor `ro.sf.lcd_density`: 420, giving 2.625 physical pixels per dp.
- `config_mainBuiltInDisplayCutout`: centered path from -36.95 to +36.95 dp,
  about 194 pixels wide, roughly 78 pixels deep.
- Vendor `status_bar_height_portrait`: 83px. `rounded_corner_radius`: 151px.
- Center avoidance: x=440, width=200, height=83; approximately 3px clearance
  on each side of the vendor notch bounds. Panel height is 83px.
- Corner avoidance: width=75, from the guide's corner-radius approximation
  using r=151 and h=83.
- Expanded mode (2026-10-19): height 147px, following the UBports
  DisplayCutouts example (FP4: 1080px wide, GridUnit 21, collapsed 81,
  expanded 147). The earlier note reusing the 83px collapsed geometry for the
  expanded panel deviated from that convention; the owner reported odd
  expanded-panel spacing. Horizontal positions stay vendor-derived. Fine-tune
  with the tool-notch-helper app the docs recommend.

Validate on-device in dark/light mode and expanded indicators, including clock,
battery percentage and both SIM indicators. The values are grounded in the
vendor geometry; final icon spacing remains a visual check.
