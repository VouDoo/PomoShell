#
# Script module for module 'PomoShell'
#

#Requires -PSEdition Core
#Requires -Version 7.0
#Requires -Module BurntToast

enum PhaseStatus {
    New
    Running
    Paused
    Skipped
    Aborted
}

class Phase {
    [string] $Name
    [uint] $Duration  # In minute
    [uint] $Turn
    hidden [PhaseStatus] $Status
    hidden [datetime] $StartDate
    hidden [datetime] $EndDate
    hidden [datetime] $PauseDate
    hidden [uint] $SecondsRemainingAtPause

    Phase(
        [string] $Name,
        [uint] $Duration,
        [uint] $Turn
    ) {
        $this.Name = $Name
        $this.Duration = $Duration
        $this.Turn = $Turn
        $this.Status = [PhaseStatus]::"New"
    }

    [void] Start() {
        if ($this.Status -eq [PhaseStatus]::"New") {
            Write-Debug -Message ("[Phase] {0} started (Turn {1})." -f $this.Name, $this.Turn)
            $this.StartDate = Get-Date
            $this.EndDate = $this.StartDate.AddMinutes($this.Duration)
            $this.Status = [PhaseStatus]::"Running"
        }
    }

    [void] Pause() {
        if ($this.Status -eq [PhaseStatus]::"Running") {
            Write-Debug -Message ("[Phase] {0} paused." -f $this.Name)
            $this.SecondsRemainingAtPause = $this.GetSecondsRemaining()
            $this.PauseDate = Get-Date
            $this.Status = [PhaseStatus]::"Paused"
        }
    }

    [void] Resume() {
        if ($this.Status -eq [PhaseStatus]::"Paused") {
            Write-Debug -Message ("[Phase] {0} resumed." -f $this.Name)
            $this.EndDate = (Get-Date).AddSeconds($this.SecondsRemainingAtPause)
            $this.Status = [PhaseStatus]::"Running"
        }
    }

    [void] Skip() {
        Write-Debug -Message ("[Phase] {0} skipped." -f $this.Name)
        $this.EndDate = Get-Date
        $this.Status = [PhaseStatus]::"Skipped"
    }

    [void] Abort() {
        Write-Debug -Message ("[Phase] {0} aborted." -f $this.Name)
        $this.EndDate = Get-Date
        $this.Status = [PhaseStatus]::"Aborted"
    }


    [bool] IsRunning() {
        if ($this.Status -eq [PhaseStatus]::"Running") {
            return $true
        }
        return $false
    }

    [bool] IsPaused() {
        if ($this.Status -eq [PhaseStatus]::"Paused") {
            return $true
        }
        return $false
    }

    [bool] IsCompleted() {
        switch ($this.Status) {
            $([PhaseStatus]::"New") {
                return $false
            }
            $([PhaseStatus]::"Skipped" -or [PhaseStatus]::"Aborted") {
                return $true
            }
            $([PhaseStatus]::"Paused") {
                if ($this.SecondsRemainingAtPause -gt 0) {
                    return $false
                }
            }
            $([PhaseStatus]::"Running") {
                $Now = Get-Date
                if ($Now -ge $this.StartDate -and $Now -le $this.EndDate) {
                    return $false
                }
            }
        }
        return $true
    }

    [double] GetSecondsRemaining() {
        if ($this.IsPaused()) {
            return $this.SecondsRemainingAtPause
        }
        return ($this.EndDate - (Get-Date)).TotalSeconds
    }

    [int] GetPercentComplete() {
        return 100 - (($this.GetSecondsRemaining() / ($this.Duration * 60)) * 100)
    }

    [string] GetActivityName() {
        return "{0} - Turn {1}" -f $this.Name, $this.Turn
    }

    [string] GetStatusDescription() {
        if ($this.IsRunning()) {
            return "{0} (ends at {1})" -f $this.Status, $this.EndDate.ToShortTimeString()
        }
        elseif ($this.IsPaused()) {
            return "{0} (at {1})" -f $this.Status, $this.PauseDate.ToShortTimeString()
        }
        return $this.Status
    }

    [hashtable] GetEndStats() {
        if ($this.IsCompleted()) {
            return @{
                StartDate = $this.StartDate
                EndDate = $this.EndDate
                TotalMinutes = [Math]::Floor(($this.EndDate - $this.StartDate).TotalMinutes)
            }
        }
        return $null
    }

    [string] ToString() {
        return "{0}, {1} minutes, turn {2}" -f $this.Name, $this.Duration, $this.Turn
    }
}

function Invoke-Toast {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Text
    )

    begin {
        $BurntToastNotification = @{
            Text    = "PomoShell", $Text
            AppLogo = Join-Path -Path $PSScriptRoot -ChildPath "PomoShell.png"
            Silent  = $true
            Confirm = $false
        }
    }

    process {
        try {
            New-BurntToastNotification @BurntToastNotification
            Write-Debug -Message ("[Toast] Shows `"{0}`"." -f $Text)
        }
        catch {
            Write-Error -Message ("[Toast] Cannot show `"{0}`": {1}" -f $Text, $_.Exception.Message)
        }
    }
}

function Invoke-Speech {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Text
    )

    begin {
        <# SpeechVoiceSpeakFlags
        - SVSFDefault = 0 # Sync
        - SVSFlagsAsync = 1 # Async
        Note: If it was me, I would go for asynchronous. Unfortunately, it is buggy...
        #>
        $SPVoiceFlag = 0
    }

    process {
        try {
            $SPVoice = New-Object -ComObject SAPI.SPVoice
            $EnglishVoice = $SPVoice.GetVoices() | Where-Object -Property Id -Match ".*\\TTS_MS_EN-.*" | Select-Object -First 1
            if ($EnglishVoice) {
                $SPVoice.Voice = $EnglishVoice
            }
            else {
                Write-Warning -Message ("[Speech] No English voice found.")
            }
            $SPVoice.Speak($Text, $SPVoiceFlag) | Out-Null
            Write-Debug -Message ("[Speech] Says `"{0}`" with `"{1}`"." -f $Text, $SPVoice.Voice.GetDescription())
        }
        catch {
            Write-Error -Message ("[Speech] Cannot say `"{0}`": {1}" -f $Text, $_.Exception.Message)
        }
    }
}

function Push-Notification {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Text,

        [Parameter()]
        [bool] $NoToast = $false,

        [Parameter()]
        [bool] $NoSpeech = $false
    )
    process {
        if (-not $NoToast) {
            Invoke-Toast -Text $Text
        }
        if (-not $NoSpeech) {
            Invoke-Speech -Text $Text
        }
    }
}

function Invoke-Pomodoro {
    <#
    .SYNOPSIS
    Invokes pomodoro.

    .DESCRIPTION
    Invokes a pomodoro in your Powershell console.

    .PARAMETER FocusDuration
    Duration of a focus time in minute.

    .PARAMETER ShortBreakDuration
    Duration of a short break time in minute.

    .PARAMETER LongBreakDuration
    Duration of a long break time in minute.

    .PARAMETER LongBreakInterval
    Interval when a long break is triggered.

    .PARAMETER NoToastNotification
    Interval when a long break is triggered.

    .PARAMETER NoVoiceNotification
    Interval when a long break is triggered.

    .PARAMETER SkipHelp
    Skip Help message

    .INPUTS
    None. You cannot pipe objects to Invoke-Pomodoro.

    .OUTPUTS
    PSCustomObject. The detailed phases that were done during the execution of the pomodoro.

    .EXAMPLE
    PS> Invoke-Pomodoro
    Start pomodoro with the default durations.

    .EXAMPLE
    PS> Invoke-Pomodoro -Focus 15 -ShortBreak 3 -LongBreak 10 -Interval 3
    Start pomodoro with custom durations.

    .EXAMPLE
    PS> Invoke-Pomodoro -NoToast -NoVoice
    Start pomodoro with all notifications turned off.

    .LINK
    GitHub repository: https://github.com/VouDoo/PomoShell

    .NOTES
    Key bindings:
        o <Space>: Pause or resume the current phase.
        o <S>:     Skip the current phase.
        o <Q>:     Stop the pomodoro.
    #>

    [CmdletBinding()]
    param(
        [Parameter(HelpMessage = "Duration of a focus time in minute")]
        [Alias("Focus")]
        [uint] $FocusDuration = 25,

        [Parameter(HelpMessage = "Duration of a short break time in minute")]
        [Alias("ShortBreak")]
        [uint] $ShortBreakDuration = 5,

        [Parameter(HelpMessage = "Duration of a long break time in minute")]
        [Alias("LongBreak")]
        [uint] $LongBreakDuration = 15,

        [Parameter(HelpMessage = "Interval when a long break is triggered")]
        [Alias("Interval")]
        [uint] $LongBreakInterval = 4,

        [Parameter(HelpMessage = "No Windows Toast notification will be shown")]
        [Alias("NoToast")]
        [switch] $NoToastNotification,

        [Parameter(HelpMessage = "No voice notification will be triggered")]
        [Alias("NoVoice")]
        [switch] $NoVoiceNotification,

        [Parameter(HelpMessage = "Skip Help message")]
        [switch] $SkipHelp
    )

    begin {
        $Continue = $true  # For the main loop
        $Turn = 1  # turn = focus time + break time
        $BreakPhase = $false
        $CompletedPhases = @()
        $NotificationOptions = @{
            NoToast  = $NoToastNotification.IsPresent
            NoSpeech = $NoVoiceNotification.IsPresent
        }
    }

    process {
        Write-Debug -Message "[Pomo] STARTED."
        while ($Continue) {
            # Create Phase object
            if ($BreakPhase) {
                if (($Turn % $LongBreakInterval) -eq 0) {
                    $Phase = New-Object -TypeName Phase -ArgumentList "Long Break", $LongBreakDuration, $Turn
                }
                else {
                    $Phase = New-Object -TypeName Phase -ArgumentList "Short Break", $ShortBreakDuration, $Turn
                }
                $BreakPhase = $false
                $Turn++
            }
            else {
                $Phase = New-Object -TypeName Phase -ArgumentList "Focus", $FocusDuration, $Turn
                $BreakPhase = $true
            }
            Write-Debug -Message ("[Pomo] Phase initiated: {0}." -f $Phase.ToString())

            $Phase.Start()

            Push-Notification @NotificationOptions -Text ("{0} has started." -f $Phase.Name)

            $Host.UI.RawUI.FlushInputBuffer()
            while (-not $Phase.IsCompleted() -and $Continue) {
                # Key actions
                if ($Host.UI.RawUI.KeyAvailable) {
                    $Key = $Host.UI.RawUI.ReadKey("NoEcho, IncludeKeyDown")
                    Write-Debug -Message "[ReadKey] $Key."
                    switch ($Key.VirtualKeyCode) {
                        # [Space] Pause/Resume the current phase
                        32 {
                            if ($Phase.IsRunning()) {
                                $Phase.Pause()
                            }
                            elseif ($Phase.IsPaused()) {
                                $Phase.Resume()
                            }
                        }
                        # [S] Skip the current phase
                        83 {
                            $Phase.Skip()
                        }
                        # [Q] Stop the pomodoro
                        81 {
                            $Phase.Pause()
                            $IsAnswered = $false
                            while (-not $IsAnswered) {
                                switch ((Read-Host -Prompt "Do you want to stop the pomodoro? [Y/N]").Trim().ToLower()) {
                                    "y" {
                                        $IsAnswered = $true
                                        $Continue = $false
                                        $Phase.Abort()
                                        Write-Debug -Message "[Pomo] Stopping..."
                                    }
                                    "n" {
                                        $IsAnswered = $true
                                        $Phase.Resume()
                                    }
                                }
                            }
                        }
                    }
                    $Host.UI.RawUI.FlushInputBuffer()
                }

                $Progress = @{
                    Activity         = $Phase.GetActivityName()
                    Status           = $Phase.GetStatusDescription()
                    PercentComplete  = $Phase.GetPercentComplete()
                    SecondsRemaining = $Phase.GetSecondsRemaining()
                }
                Write-Progress @Progress
                #Start-Sleep -Milliseconds 500  # To pause between each loop
            }

            Write-Progress -Activity $Phase.GetActivityName() -Completed

            Push-Notification @NotificationOptions -Text ("{0} has ended." -f $Phase.Name)

            $PhaseEndStats = $Phase.GetEndStats()
            $CompletedPhases += [PSCustomObject] @{
                Phase        = $Phase.Name
                Turn         = $Phase.Turn
                Start        = $PhaseEndStats.StartDate
                End          = $PhaseEndStats.EndDate
                TotalMinutes = $PhaseEndStats.TotalMinutes
            }

            Write-Debug -Message ("[Pomo] Phase completed: {0}." -f $Phase.ToString())
        }

        Write-Debug -Message "[Pomo] STOPPED."
    }

    end {
        Write-Debug -Message "[Pomo] Returns completed phases."
        $CompletedPhases
    }
}

# Create alias(es)
New-Alias -Name Pomo -Value "Invoke-Pomodoro"

# export member(s)
Export-ModuleMember -Function Invoke-Pomodoro -Alias Pomo
