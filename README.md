# BA Custom Click Builder

A lightweight Windows utility for building, saving, and replaying sequences of mouse clicks across multiple monitors. Designed for golf simulator facilities and any other setup where a tech needs to automate a repeatable series of on-screen clicks with precise timing.

Built and maintained by **BA Custom Products**.

---

## Download

### [>> Download ClickBuilder.exe (Latest Release) <<](https://github.com/DiyGolfGuy/Golf-Simulator-Start-up-Click-Builder/releases/latest)

[![Latest Release](https://img.shields.io/github/v/release/DiyGolfGuy/Golf-Simulator-Start-up-Click-Builder?label=Latest%20Release&style=for-the-badge)](https://github.com/DiyGolfGuy/Golf-Simulator-Start-up-Click-Builder/releases/latest)

No installer, no dependencies, no admin rights required. Just download and run.

[View all releases](https://github.com/DiyGolfGuy/Golf-Simulator-Start-up-Click-Builder/releases)

---

## What It Does

Click Builder lets you visually record a series of mouse clicks on any monitor, assign a wait time and click type (single or double) to each one, and then either run them immediately or export the whole sequence as a standalone AutoHotkey macro you can run on its own.

Typical use cases:

- Launching and configuring software that has no command-line interface
- Starting a golf simulator sequence across multiple windows on multiple displays
- Any repetitive click-through workflow a staff member has to do by hand

---

## How It Works

The tool uses three simple stages per step:

1. **Wait** the number of milliseconds you specified before this step (lets the previous window finish loading)
2. **Move** the mouse to the target coordinates
3. **Settle** for 200ms so the OS registers the new position
4. **Click** (single or double)

Each click you record stores its absolute screen coordinates, which monitor it lives on, the wait time, and the click type. You can reorder, edit, delete, or duplicate steps in the list before running or saving.

The builder is fully **Per-Monitor DPI Aware (V2)**, meaning it captures and replays clicks correctly even when each monitor is running at a different Windows display scaling percentage.

---

## Requirements

- Windows 10 or Windows 11
- For running the `.exe`: nothing extra, it is self-contained
- For running the `.ahk` source: AutoHotkey v1.1 (v2 is not supported)

---

## Installation

### Option 1: Run the compiled .exe (recommended)

1. **[Download ClickBuilder.exe here](https://github.com/DiyGolfGuy/Golf-Simulator-Start-up-Click-Builder/releases/latest)**
2. Place it anywhere you like (Desktop, Program Files, a USB stick, wherever)
3. Double-click to launch

No installer. No dependencies. No admin rights required.

### Option 2: Run the .ahk source

1. Install AutoHotkey v1.1 from https://www.autohotkey.com
2. Download `ClickBuilder.ahk` from this repository
3. Double-click the file to run it

---

## How to Use

### Building a Click Sequence

1. Launch Click Builder
2. Click **Pick Next Click** (or press `F2`)
3. The builder window hides and a tooltip appears
4. Click anywhere on any monitor at the exact spot you want automated
5. A dialog asks whether this is a **Single Click** or **Double Click**
6. Enter the **wait time in milliseconds** before this step runs (e.g. 3000 for a 3-second wait)
7. The step is added to the list

Repeat for every click you want in the sequence. You can use the row buttons to move steps up/down, edit them, or remove them.

### Running the Sequence

- **Run Now** plays the sequence once from inside the builder
- **Save As .ahk** exports the sequence as a standalone AutoHotkey macro you can run on its own without needing Click Builder installed

### Saving and Loading

- **Save Macro** exports the current sequence as an `.ahk` file that is fully self-contained. It includes its own on-screen display (OSD) banner so the operator knows to keep their hands off the mouse while it runs.
- **Load Macro** reads an existing `.ahk` file back into the builder so you can edit it.

### Monitor Info

Click **Show Monitors** at any time to see how many monitors Windows has detected, their virtual screen layout, and the pixel bounds of each one. Useful for confirming your multi-display setup before recording clicks.

---

## Troubleshooting

### The click lands in the wrong spot when I pick a point on my TV (or second monitor)

**First, check your display scaling.** Open Windows Settings > System > Display, click each monitor, and check the **Scale** percentage. If your monitors are running at different percentages (for example, TV at 100% and projector at 150%), that is the most common cause of misfires.

Click Builder is built with per-monitor DPI awareness and should handle mixed scales correctly. However, if you are still seeing misfires with mixed scaling, **set all monitors to the same scaling percentage** as a reliable workaround.

To do this:
1. Open Settings > System > Display
2. Click each monitor in turn
3. Set the **Scale and layout** value to the same percentage for every display (100% is usually safest)
4. Sign out and back in if Windows asks you to
5. Relaunch Click Builder and re-record your clicks

### Old saved macros still misfire after updating Click Builder

Exported `.ahk` macros are self-contained, which means they contain the same click logic that was current at the time of export. If you export a macro from an older version of Click Builder and then update Click Builder, **re-export** your saved macros so they pick up the latest fixes.

### The macro runs but clicks fire too fast or too slow

Edit the **Wait (ms)** value on each step. A good starting point is 500ms for simple interface clicks and 2000 to 5000ms for steps that follow the launch of an application or the loading of a new screen.

### Windows Defender or SmartScreen warns about the .exe

This is normal for any unsigned AutoHotkey-compiled executable. You can either click **More info > Run anyway**, or run the `.ahk` source directly with AutoHotkey installed.

---

## Files in This Repository

| File | Purpose |
|---|---|
| `ClickBuilder.ahk` | AutoHotkey v1 source code |
| `README.md` | This file |
| `icon.ico` | Icon used for the compiled build |

The compiled `ClickBuilder.exe` is distributed through the [Releases page](https://github.com/DiyGolfGuy/Golf-Simulator-Start-up-Click-Builder/releases) rather than committed to the repository.

---

## Compiling from Source

If you want to build your own `.exe` from the source file:

1. Install AutoHotkey v1.1 which includes Ahk2Exe
2. Make sure `ClickBuilder.ahk` and `icon.ico` are in the same folder
3. Right-click `ClickBuilder.ahk` and choose **Compile Script**, or run Ahk2Exe from the command line:

   ```
   "C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe" /in ClickBuilder.ahk /out ClickBuilder.exe /icon icon.ico
   ```

4. The resulting `ClickBuilder.exe` is fully standalone.

The `.ahk` source contains an `;@Ahk2Exe-SetMainIcon icon.ico` directive, so any compile method will automatically use `icon.ico` as long as it is in the same folder.

---

## License

Released by BA Custom Products for use by golf simulator operators and the wider AutoHotkey community. Use it, modify it, ship it with your own facility tools. No warranty expressed or implied.

---

## Contact

**BA Custom Products**
Email: bacustomproducts@gmail.com
Phone: (218) 684-3290

