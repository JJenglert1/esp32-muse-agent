# Build Your Own Pocket AI Agent for About $30

**Turn a tiny touchscreen gadget into a personal AI agent you can talk to.**
Hold a button, ask a question, and it answers out loud with a cute animated face.
It runs on Meta's free, open source [Muse Gadget SDK](https://github.com/facebookincubator/muse-gadget-sdk),
and this guide walks you through it step by step. No soldering, and you don't need to be a programmer.

<!-- Add a photo or GIF of the finished gadget here: ![My Muse gadget](docs/gadget.jpg) -->

## What you'll end up with

- 🗣️ **A voice agent in your pocket.** Hold the button, talk, let go. Your Muse agent answers.
- 🔊 **It talks back.** Muse gadgets normally show replies as text only. This guide adds a real voice.
- 😊 **An animated face** on a bright AMOLED touchscreen.
- 🔋 **Battery powered** (optional), so it works anywhere on Wi-Fi.
- 🧠 **Your own Muse agent**, the same one in the Muse phone app, with your memory and tools.

**Time:** about 1 hour. **Cost:** about $30 for the board, plus pennies a day for the voice.

---

## Step 1: Pick your gadget

You need an ESP32 board with a **screen, a microphone, a speaker, and extra memory (PSRAM)**.
These all work:

| Board | Price | Why pick it | Buy |
|---|---|---|---|
| ⭐ **Waveshare ESP32-S3-Touch-AMOLED-1.8 (V2)** | ~$28 | What this guide was built on. Bright 1.8" AMOLED touchscreen, mic, speaker, battery connector. Needs this repo's patch. | [Waveshare](https://www.waveshare.com/esp32-s3-touch-amoled-1.8.htm) |
| **Waveshare ESP32-S3-Touch-AMOLED-1.75C** | ~$40 | Officially supported by Muse. Round screen, two mics, sleek aluminum case. | [Waveshare](https://www.waveshare.com/product/esp32-related/displays/amoled/esp32-s3-touch-amoled-1.75c.htm) · [Amazon](https://www.amazon.com/dp/B0GGY19TF9) |
| **Waveshare ESP32-S3-Touch-AMOLED-1.75** | ~$30 | Officially supported. Same round screen, plastic case option. | [Waveshare](https://www.waveshare.com/esp32-s3-touch-amoled-1.75.htm) · [Amazon](https://www.amazon.com/dp/B0F7XTJ7JW) |
| **M5Stack StickS3** | ~$22 | Cheapest option. Officially supported, tiny, battery built in. Small screen. | [M5Stack](https://shop.m5stack.com/products/m5sticks3-esp32s3-mini-iot-dev-kit) · [Amazon](https://www.amazon.com/dp/B0GWHN8HK3) |
| **AIPI Lite** | ~$36 | Officially supported. Made to be a voice gadget, battery included. | [AIPI](https://aipi.com/products/aipi-lite) · [Amazon](https://www.amazon.com/dp/B0HFRS7BQ8) |
| **Espressif ESP32-S3-BOX-3** | ~$50 | Officially supported. Bigger 2.4" screen, great for a desk. | [Adafruit](https://www.adafruit.com/product/5835) |
| **Seeed SenseCAP Watcher** | ~$55 | Officially supported. Has a camera too. | [Seeed](https://www.seeedstudio.com/SenseCAP-Watcher-W1-B-p-5980.html) |

**Skip these:** the Waveshare ESP32-**C6**-Touch-AMOLED-1.8 (no PSRAM, so no voice add-on), the M5Stack
StickC Plus2 (discontinued, buzzer instead of a speaker), and boards with no microphone or speaker.

> **Buying the 1.8" board?** Get the **V2**. Waveshare switched to V2 in May 2026, and the label on
> the back says which one you have. Some Amazon listings still describe V1 (SH8601 screen, FT3168
> touch), which this guide does not support. Buying from Waveshare directly is the safe bet.

You also need:

- A **USB-C cable that carries data** (not a charge-only cable)
- A **Mac or Linux computer**
- A **phone** with the Muse app
- Optional: a small **3.7 V battery** with an MX1.25 plug, if your board doesn't include one

---

## Step 2: Get your Muse account and SDK token (free)

[Muse](https://gadgets.muse.ai/) is Meta's personal AI agent. The Gadget SDK is **free and open source**,
and Muse has a **free plan with a weekly usage limit**. Paid plans give you more if you need it.
Check [Muse's current plans](https://www.meta.com/help/subscriptions/1021145227643680/) before you start.

1. Install **Muse from Meta** on your phone ([iPhone](https://apps.apple.com/us/app/muse-from-meta/id6760173601)) and sign in.
2. On a computer, go to [gadgets.muse.ai/settings/sdk-tokens](https://gadgets.muse.ai/settings/sdk-tokens)
   with the same account and create an **SDK token**. It starts with `mgst_`.
3. Keep it handy, and keep it private. It's like a password for your gadgets.

Good to know:

- You must be **18 or older** to use Muse, and it's currently available in the US and Canada.
- One token works for up to **50 gadgets**, for **personal, non-commercial use**. Read the
  [SDK terms](https://gadgets.muse.ai/sdk-terms).
- If a token ever leaks, delete it on that page and make a new one.

---

## Step 3: Install the tools (one time)

Open **Terminal** and paste these one at a time. On a Mac, you need [Homebrew](https://brew.sh) first.

```bash
brew install cmake ninja dfu-util python3 git
```

Install ESP-IDF 6.0.1, Espressif's toolkit. Muse needs **exactly** this version. This step takes 10 to 20 minutes.

```bash
mkdir -p ~/esp && git clone -b v6.0.1 --recursive --depth 1 --shallow-submodules https://github.com/espressif/esp-idf.git ~/esp/esp-idf-v6 && ~/esp/esp-idf-v6/install.sh esp32s3
```

> Keep this folder somewhere without spaces in its path. Spaces break the toolkit.

---

## Step 4: Download this guide and the Muse SDK

```bash
git clone https://github.com/JJenglert1/esp32-muse-agent.git && cd esp32-muse-agent && ./scripts/setup.sh
```

This downloads Meta's Muse Gadget SDK at the version this guide was tested on, then adds:

- Support for the **Waveshare AMOLED 1.8 V2** board
- **Spoken replies** (Step 7)
- **60-second voice notes** (up from 15)
- A **forgiving talk button**, so a slight finger slip doesn't cut you off mid-sentence

---

## Step 5: Add your token and build

```bash
./scripts/configure.sh
```

It asks for your **Muse SDK token** and, optionally, an **OpenAI key** for the voice (see Step 7, or just
press Return to skip for now). What you type is hidden. Then it builds the firmware, which takes a
few minutes the first time.

Using a different board? Add its short name, for example `./scripts/configure.sh s3` for the
1.75C or `./scripts/configure.sh sticks3` for the StickS3. The full list is in
`muse-gadget-sdk/esp32/tools/muse/board.sh`.

> Your token is saved only in the build folder, which git ignores, so it never ends up on GitHub.
> It is compiled into the device, so don't give away a gadget that has your token on it.

---

## Step 6: Put it on the gadget and pair it

Plug the board in with your data cable. Run these from the `esp32-muse-agent` folder.

**1. Back up what's on it now (recommended).** This copies the whole chip to a file and changes nothing,
so you can always go back to the original software.

```bash
. ~/esp/esp-idf-v6/export.sh && esptool --chip esp32s3 read-flash 0 ALL backup-$(date +%Y%m%d).bin
```

**2. Wipe the old software.** Muse keeps its settings where the old software lived, and leftovers can
confuse it. Only do this after the backup above.

```bash
esptool --chip esp32s3 erase-flash
```

**3. Flash Muse:**

```bash
cd muse-gadget-sdk/esp32 && tools/muse/board.sh flash s318
```

(Use your board's short name instead of `s318` if it's not the AMOLED 1.8.)

If the screen stays dark after flashing, unplug the USB cable for 5 seconds and plug it back in.

Now pair it with your phone:

1. In the Muse app, go to **Settings > Devices** and turn on **Developer mode**.
2. Tap the **+** at the top right. Your gadget shows up as **MuseGadget-XXXXXX**.
3. When the gadget asks, press its **talk button** to confirm it's really you.
   On the AMOLED 1.8, that's the **top** side button.
4. Pick your Wi-Fi and enter the password. **Tip:** on iPhone, go to Settings > Wi-Fi, tap ⓘ next to
   your network, and copy the password, then paste it in. Typos here are the #1 cause of trouble.

The face appears and the status turns green. **Hold the talk button, ask something, let go.** 🎉

---

## Step 7: Give your agent a voice

Out of the box, Muse gadgets show replies as text. This guide's patch adds a real voice using
OpenAI's text-to-speech. It costs about **1.5 cents per minute of speech**, so a few dollars a month
for normal use.

1. Make an account at [platform.openai.com](https://platform.openai.com) and add a few dollars of credit.
2. Set a **monthly budget** under [Settings > Limits](https://platform.openai.com/settings/organization/limits),
   for example $5.
3. Create a key at [platform.openai.com/api-keys](https://platform.openai.com/api-keys). It starts with `sk-`.
4. Run `./scripts/configure.sh` again, paste your token, then paste the key when asked.
5. Flash again (Step 6). Your Wi-Fi and pairing stay. Only the app changes.

**Change the voice:** the default is `coral`, warm and natural. Others include `alloy`, `ash`, `ballad`,
`echo`, `fable`, `nova`, `onyx`, `sage`, `shimmer`, `verse`, `marin` and `cedar`. To switch, edit
`CONFIG_MUSE_TTS_OPENAI_VOICE` in `muse-gadget-sdk/esp32/build-muse-<board>/sdkconfig`, then build and
flash again. You can also change the speaking style with `CONFIG_MUSE_TTS_OPENAI_INSTRUCTIONS`, for example
"Speak like an excited sports announcer."

> **Heads up:** the key is stored inside the gadget, and someone with the device and some skill could
> read it out. That's why the spending limit matters. Use a separate key just for this gadget.
> OpenAI also asks that you tell listeners the voice is AI-generated.

---

## Fixing common problems

| What you see | What to do |
|---|---|
| Won't join Wi-Fi | Almost always a wrong password. Copy and paste it (see Step 6). Guest networks with WPA3-only security can also fail; try your main network. |
| "Token rejected" | On the gadget's own Muse settings screen, make sure **Device token** says **Not set**. Typing anything there overrides your phone pairing. Tap it, delete everything, tap Done. |
| No **+** in the Muse app | Turn on **Developer mode** first, and update the app. |
| It hears only your first word or two | Hold the talk button the whole time you speak. This guide's patch ignores quick slips. |
| "No reply from Muse" | Muse's servers sometimes take a while. Try again. |
| Voice doesn't play | Check that your OpenAI key has credit, and that the gadget's speaker isn't muted. If it fails, it falls back to text. |
| It shut off | On the AMOLED 1.8, the **bottom** button is power. Hold it to turn off. |

Stuck? Ask in the [Muse gadgets Discord](https://discord.gg/3bhjCkZdd6).

---

## 10 fun things to try with your Muse agent

1. **Kitchen helper.** Prop it by the stove and ask for the next recipe step or a quick conversion with messy hands.
2. **Morning briefing.** Ask for a quick rundown of the news, the weather, and anything your Muse agent knows about your day.
3. **Smart home remote.** Muse's SDK includes guides for controlling things like Sonos, Philips Hue and
   Google Home on your home network ([skills folder](https://github.com/facebookincubator/muse-gadget-sdk/tree/main/skills)).
4. **Desk buddy.** A tiny always-there assistant for quick math, spelling, definitions, and "what was that actor's name?"
5. **Language practice.** Have it quiz you on Spanish or French words and phrases, out loud.
6. **Brain dump.** Hold the button for up to a minute and talk through an idea. Ask Muse to turn it into a to-do list.
7. **Workshop or garage assistant.** Torque specs, wire gauges and step-by-step help, hands-free.
8. **Trivia night host.** "Ask me 5 movie trivia questions and keep score."
9. **Custom character.** Change the voice and speaking style to build a pirate, a butler, or a hype coach.
10. **Your own mini product.** Fork this repo, change the face (Muse includes an avatar tool), and build
    the gadget you always wanted, from a meeting timer to a plant-care buddy.

---

## How it works (for the curious)

- The gadget handles the button, mic, screen and speaker. **All the thinking happens in the cloud** with Muse.
- Your voice goes to Muse as a voice note. Muse sends back its reply as text.
- This patch sends that text to OpenAI's speech API and plays the MP3 through the speaker, with captions in step.
- Developer notes, including what broke and why, are in [docs/lessons-learned.md](docs/lessons-learned.md).

## Credits and license

- [Muse Gadget SDK](https://github.com/facebookincubator/muse-gadget-sdk) by Meta, Apache 2.0.
- This guide and patch are Apache 2.0 too. See [LICENSE](LICENSE).
- Not affiliated with Meta, Waveshare, M5Stack, Espressif, Seeed, AIPI or OpenAI.
- Flashing custom firmware is at your own risk. Back up first (Step 6).
