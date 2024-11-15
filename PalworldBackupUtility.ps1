# Function to backup save files
function Backup-SaveFiles {
    $sourceFolder = "$env:USERPROFILE\AppData\Local\Pal\Saved"
    $datestamp = Get-Date -Format "yyyy-MM-dd"
    $timestamp = Get-Date -Format "HH-mm-ss-tt"

    # Load destination folder from file or prompt user
    $destinationFolder = if (Test-Path "backup_path.txt") {
        Get-Content "backup_path.txt"
    } else {
        $folderPicker = New-Object System.Windows.Forms.FolderBrowserDialog
        $folderPicker.Description = "Select a folder for backup"
        if ($folderPicker.ShowDialog() -eq "OK") {
            $folderPicker.SelectedPath | Out-File "backup_path.txt"
            $folderPicker.SelectedPath
        } else {
            return # User cancelled
        }
    }

    $zipFile = Join-Path $destinationFolder "PalworldBackup_$datestamp_$timestamp.zip"

    Write-Host "Creating zip file: $zipFile..."
    try {
        Compress-Archive -LiteralPath $sourceFolder -DestinationPath $zipFile -Force -ErrorAction Stop
        Write-Host "Backup completed."
    }
    catch {
        Write-Error "Failed to create backup."
    }
}

# Function to restore backup
function Restore-Backup {
    $backupFolder = if (Test-Path "backup_path.txt") {
        Get-Content "backup_path.txt"
    } else {
        $folderPicker = New-Object System.Windows.Forms.FolderBrowserDialog
        $folderPicker.Description = "Select the backup folder"
        if ($folderPicker.ShowDialog() -eq "OK") {
            $folderPicker.SelectedPath | Out-File "backup_path.txt"
            $folderPicker.SelectedPath
        } else {
            return # User cancelled
        }
    }

    $filePicker = New-Object System.Windows.Forms.OpenFileDialog
    $filePicker.InitialDirectory = $backupFolder
    $filePicker.Filter = "Zip Files (*.zip)|*.zip"
    if ($filePicker.ShowDialog() -eq "OK") {
        $selectedBackup = $filePicker.FileName

        Write-Host "Restoring selected backup..."
        try {
            Expand-Archive -LiteralPath $selectedBackup -DestinationPath "$env:USERPROFILE\AppData\Local\Pal" -Force -ErrorAction Stop
            Write-Host "Backup restored successfully."
        }
        catch {
            Write-Error "Failed to restore backup."
        }
    }
}


function Create-ScheduledBackup {
    $taskName = "Palworld Automated Backup"
    $taskDescription = "Automates the backup of Palworld save files daily."

    # Check if the task already exists
    if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
        [System.Windows.Forms.MessageBox]::Show("A scheduled task for Palworld backup already exists.", "Information", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        return
    }

    # Verify the backup destination path
    $destinationFolder = if (Test-Path "backup_path.txt") {
        Get-Content "backup_path.txt"
    } else {
        [System.Windows.Forms.MessageBox]::Show("Please set the backup location first.", "Information", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        return
    }

    # Create a custom form to ask for the time input
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Enter Backup Time"
    $form.Size = New-Object System.Drawing.Size(300, 150)
    $form.StartPosition = "CenterScreen"

    # Create label for time input
    $label = New-Object System.Windows.Forms.Label
    $label.Text = "Enter backup time (HH:mm):"
    $label.Location = New-Object System.Drawing.Point(10, 20)
    $label.Size = New-Object System.Drawing.Size(150, 20)
    $form.Controls.Add($label)

    # Create TextBox for time input
    $timeInputBox = New-Object System.Windows.Forms.TextBox
    $timeInputBox.Location = New-Object System.Drawing.Point(10, 50)
    $timeInputBox.Size = New-Object System.Drawing.Size(100, 20)
    $form.Controls.Add($timeInputBox)

    # Create OK button
    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = "OK"
    $okButton.Location = New-Object System.Drawing.Point(10, 80)
    $okButton.Add_Click({
        $form.Close()
    })
    $form.Controls.Add($okButton)

    # Show the form and wait for user input
    $form.ShowDialog()

    # Get the input time
    $timeInput = $timeInputBox.Text

    # Validate the time input
    if (-not $timeInput) {
        [System.Windows.Forms.MessageBox]::Show("You must enter a time in HH:mm format.", "Invalid Input", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    try {
        $backupTime = [datetime]::ParseExact($timeInput, "HH:mm", $null)
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Invalid time format. Please enter time in HH:mm format.", "Invalid Time", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }

    # Create a standalone script for the backup function
    $currentFolder = (Get-Location).Path
    $scriptPath = Join-Path $currentFolder "Palworld_AutoBackup.ps1"
    $backupScriptContent = @"
# Auto-generated backup script for Palworld
`$sourceFolder = `"$env:USERPROFILE\AppData\Local\Pal\Saved`"
`$destinationFolder = `"$destinationFolder`"

`$datestamp = Get-Date -Format 'yyyy-MM-dd'
`$timestamp = Get-Date -Format 'HH-mm-ss-tt'
`$zipFile = Join-Path `$destinationFolder "PalworldBackup_`$datestamp_`$timestamp.zip"

Write-Host "Creating zip file: `$zipFile..."
try {
    Compress-Archive -LiteralPath `$sourceFolder -DestinationPath `$zipFile -Force -ErrorAction Stop
    Write-Host "Backup completed."
} catch {
    Write-Error "Failed to create backup."
}
"@
    $backupScriptContent | Out-File -FilePath $scriptPath -Force -Encoding UTF8

    # Create the scheduled task
    $trigger = New-ScheduledTaskTrigger -Daily -At $backupTime
    $action = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

    try {
        Register-ScheduledTask -TaskName $taskName -Description $taskDescription -Action $action -Trigger $trigger -Settings $settings -User $env:USERNAME -Force
        [System.Windows.Forms.MessageBox]::Show("Scheduled backup created successfully. It will run daily at $($backupTime.ToString('HH:mm')).", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to create scheduled task: $_", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}





# Function to delete the scheduled task
function Delete-ScheduledBackup {
    $taskName = "Palworld Automated Backup"

    if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        [System.Windows.Forms.MessageBox]::Show("Scheduled backup task deleted.", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    } else {
        [System.Windows.Forms.MessageBox]::Show("No scheduled backup task found.", "Information", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    }
}

# GUI for user interaction
Add-Type -AssemblyName System.Windows.Forms
$form = New-Object System.Windows.Forms.Form
$form.Text = "Palworld Backup Utility"
$form.Size = New-Object System.Drawing.Size(400, 400)
$form.StartPosition = "CenterScreen"

# ASCII Art Label (optional)
$asciiLabel = New-Object System.Windows.Forms.Label
$asciiLabel.Text = @"
    ____        ___       __           __    __
   / __ \____ _/ / |     / /___  _____/ /___/ /
  / /_/ / __ `/ /| | /| / / __ \/ ___/ / __  / 
 / ____/ /_/ / / | |/ |/ / /_/ / /  / / /_/ /  
/_/    \__,_/_/  |__/|__/\____/_/  /_/\__,_/
"@
$asciiLabel.Font = New-Object System.Drawing.Font("Consolas", 10)
$asciiLabel.AutoSize = $true
$asciiLabel.Location = New-Object System.Drawing.Point(10, 0)
$form.Controls.Add($asciiLabel)

# Buttons
$backupButton = New-Object System.Windows.Forms.Button
$backupButton.Text = "Backup Save Files"
$backupButton.Location = New-Object System.Drawing.Point(10, 90)
$backupButton.AutoSize = $true
$backupButton.Add_Click({ Backup-SaveFiles })
$form.Controls.Add($backupButton)

$restoreButton = New-Object System.Windows.Forms.Button
$restoreButton.Text = "Restore Backup"
$restoreButton.Location = New-Object System.Drawing.Point(10, 130)
$restoreButton.AutoSize = $true
$restoreButton.Add_Click({ Restore-Backup })
$form.Controls.Add($restoreButton)

$setBackupLocationButton = New-Object System.Windows.Forms.Button
$setBackupLocationButton.Text = "Set Backup Save Location"
$setBackupLocationButton.Location = New-Object System.Drawing.Point(10, 170)
$setBackupLocationButton.AutoSize = $true
$setBackupLocationButton.Add_Click({
    $folderPicker = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderPicker.Description = "Select a new folder for backup"
    if ($folderPicker.ShowDialog() -eq "OK") {
        $folderPicker.SelectedPath | Out-File "backup_path.txt"
        Write-Host "Backup path updated!"
    }
})
$form.Controls.Add($setBackupLocationButton)

$scheduleButton = New-Object System.Windows.Forms.Button
$scheduleButton.Text = "Create Scheduled Backup"
$scheduleButton.Location = New-Object System.Drawing.Point(10, 210)
$scheduleButton.AutoSize = $true
$scheduleButton.Add_Click({ Create-ScheduledBackup })
$form.Controls.Add($scheduleButton)

$deleteScheduleButton = New-Object System.Windows.Forms.Button
$deleteScheduleButton.Text = "Delete Scheduled Backup"
$deleteScheduleButton.Location = New-Object System.Drawing.Point(10, 250)
$deleteScheduleButton.AutoSize = $true
$deleteScheduleButton.Add_Click({ Delete-ScheduledBackup })
$form.Controls.Add($deleteScheduleButton)

# Exit Button
$exitButton = New-Object System.Windows.Forms.Button
$exitButton.Text = "Exit"
$exitButton.Location = New-Object System.Drawing.Point(10, 300)
$exitButton.AutoSize = $true
$exitButton.Add_Click({ $form.Close() })
$form.Controls.Add($exitButton)

# Show the form
$form.ShowDialog()
