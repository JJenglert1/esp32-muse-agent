# Lessons Learned

Notes from porting the Muse Gadget SDK to the Waveshare ESP32-S3-Touch-AMOLED-1.8 **V2** and adding
spoken replies. Useful if you're porting another board or debugging this one.

## The board

| Part | Chip | Notes |
|---|---|---|
| CPU | ESP32-S3R8, 16 MB flash, 8 MB **octal** PSRAM | `CONFIG_SPIRAM_MODE_OCT=y` |
| Screen | CO5300 AMOLED, 368 x 448, QSPI | CS 12, CLK 11, D0 to D3 on 4 to 7 |
| Touch | CST820 at I2C `0x15` | Read raw: register `0x02`, 5 bytes |
| Audio | ES8311 at `0x18`, one analog mic, amp enable on GPIO 46 | I2S MCLK 16, BCLK 9, WS 45, DOUT 8, DIN 10 |
| Power | AXP2101 at `0x34` | The lower side button reaches the ESP32 only through it |
| Expander | TCA9554 at `0x20` | P0 panel reset, P1 panel power, P2 touch reset, P7 SD CS |
| I2C | SDA 15, SCL 14 | Shared by everything above |
| Buttons | Upper side = BOOT (GPIO 0) = talk. Lower side = PWR. | |

**V1 vs V2:** V1 uses an SH8601 screen and FT3168 touch (touch at `0x38`). V2 answers at `0x15`.
They need different drivers.

## Display

- The panel's 368 columns start at **x = 16**. Without that offset you get a green strip on the right edge.
- Update windows must be even-aligned.
- Brightness is panel command `0x51`, not a backlight pin.
- **SPI DMA straight from PSRAM underflows** on this panel while Wi-Fi is up. Symptoms: solid green or
  black screen, `DMA TX underflow`, `send command failed`. Muse's `muse_lcd_bands` avoids this: LVGL
  draws tall bands in PSRAM, and a task copies them a few rows at a time into two small internal
  DMA buffers. The board file uses it with 112-line bands and 5,888-byte chunks.
- Waveshare's BSP sizes SPI transfers for a full frame and pulls in `esp_lvgl_port`, so the board file
  drives the panel, touch and codec directly instead.
- Panel and touch reset order, from Waveshare's V2 examples: make expander pins outputs held low,
  wait 20 ms, set them all high, wait 150 ms.

## Flashing and boot

- Native USB can leave the chip in the ROM downloader after flashing. Unplug for 5 seconds if the screen stays dark.
- Opening the serial port with a normal monitor resets the board. For passive logs on macOS:
  `stty -f /dev/cu.usbmodemXXXX raw -hupcl clocal; cat /dev/cu.usbmodemXXXX`.
- Muse's partition table lives at `0x10000`, and its NVS overlaps where other firmware kept code.
  Erase the chip once before the first Muse flash.
- Later app-only updates (`write-flash 0x20000 muse-gadget.bin`) keep Wi-Fi and pairing.
- The AXP2101 keeps its register settings across reboots and reflashes. Muse sets a 10 s power-button
  hold-off. Only unplugging USB and battery resets it.

## Pairing

- Wi-Fi details come from the Muse phone app over Bluetooth. A disconnect with reason 15 on every retry
  means the password is wrong.
- The gadget's on-screen **Device token** field overrides the phone pairing. Anything typed there makes
  chat fail with `fetch_vms: token rejected (HTTP 401)`. Upstream ignores an empty entry, so it could
  never be cleared on the device; the patch lets an empty entry clear it.

## Spoken replies

- Muse sends gadgets text only. Upstream leaves a hook, `start_tts()` in `muse_chat_session.cpp`.
- `muse_tts_openai.c` sends each finished reply to `POST https://api.openai.com/v1/audio/speech`
  (`gpt-4o-mini-tts`, MP3) on its own task. The MP3 goes into Muse's existing minimp3 decoder and speaker path.
- **TLS gotcha:** api.openai.com presents GTS Root R4 cross-signed by GlobalSign Root CA (R1), which
  isn't in ESP-IDF 6.0.1's bundle. The fix is `CONFIG_MBEDTLS_CERTIFICATE_BUNDLE_CROSS_SIGNED_VERIFY=y`.
  A setting in an overlay file won't reach an existing build `sdkconfig` that already says "is not set".
- The TLS connection is kept open between replies and opened early while you're still talking,
  because a fresh handshake costs about a second.
- Measured on the device: OpenAI's first audio took 3.4 to 4 s with a fresh connection, and 1.3 to 1.7 s
  with the kept, pre-warmed one. Muse's own thinking (5 to 14 s) is on the server side.

## Voice notes and the talk button

- Upstream caps a press at 15 s. The patch raises it to 60 s, about 1.9 MB of PSRAM per note.
- The BOOT button is small and stiff. Upstream's 30 ms debounce turned brief finger slips into
  "let go", which cut notes off after 1 to 3 seconds. The patch only counts a release after 400 ms,
  and logs each slip it ignores (`talk key slipped for N ms; still held`).

## Process rules that saved us

1. Back up the full flash before the first write. Read it in 1 MB chunks and verify each one.
2. Change one thing per test build, and record the app's checksum, the boot log, and what the screen showed.
3. A verified flash doesn't prove the app booted. A boot doesn't prove the screen drew.
4. Check that a new build actually changed the binary. A failed build can silently leave the old one.
