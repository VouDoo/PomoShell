# PomoShell

PomoShell is a tiny module that turns your PowerShell console into a pomodoro timer.

If you do not know the pomodoro technique yet, please read this article: ["The Pomodoro Technique" by Todoist](https://todoist.com/productivity-methods/pomodoro-technique).

## License

PomoShell is released under the terms of the MIT license. See [LICENSE](LICENSE) for more information or see <https://opensource.org/licenses/MIT>.

---

## Installation

### Get PowerShell Core

Please note that the module is only available for PowerShell Core (7 or later).

Get the latest version of PS Core from [the official PowerShell repository](https://github.com/PowerShell/PowerShell/releases).

### Install the module

The module is published on PowerShell Gallery.
See <https://www.powershellgallery.com/packages/PomoShell>.

To install it, run:

```powershell
Install-Module -Name PomoShell -Repository PSGallery
```

---

## Usage

### Prepare your environment

Import the module:

```powershell
Import-Module PomoShell
```

The fastest way to use the module is to import it from your [PowerShell profile](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_profiles?view=powershell-7.1).
Then, each time you will open your PowerShell console, the module will be automatically imported.

### Start your pomodoro

To start the pomodoro, simply run:

```powershell
Pomo
```

By default, the parameters respect the traditional pomodoro technique:

| Phase | Duration |
|-|-|
| Focus | 25 minutes |
| Short break | 5 minutes |
| Long break | 15 minutes |

However, you can choose the durations for each phase. For instance:

```powershell
Pomo -Focus 15 -ShortBreak 3 -LongBreak 10
```

Also, the default interval for the long break is 4.
You can change it too. For instance:

```powershell
Pomo -Interval 3
```

### Key bindings

During the pomodoro execution, you can use keys to perform some actions.

| Key | Action |
|-|-|
| Space bar | Pause or resume the current phase |
| `S` | Skip the current phase |
| `Q` | Stop the pomodoro |

### Get Help

Use [the `Get-Help` Cmdlet](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/get-help?view=powershell-7.1) to obtain more information about the `Invoke-Pomodoro` command (Alias `Pomo`):

```powershell
Get-Help Pomo -Full
```

---

## Support

If you have some suggestions, please don't hesitate to contact me (find email on [my GitHub profile](https://github.com/VouDoo)).
