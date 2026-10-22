param(
    [ValidateSet('Audit','Snapshot','Apply','Restore','List','SelfTest')][string]$Mode = 'Audit',
    [string]$Ids = '',
    [string]$SnapshotId = '',
    [string]$DataRoot = (Join-Path $env:LOCALAPPDATA 'PrivacyDesk')
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$script:Testing = $Mode -eq 'SelfTest'
$script:Mock = @{}
$script:FailWrite = ''
$script:Catalog = @()
function Emit($Type, $Data) {
    if (-not $script:Testing) {
        [Console]::Out.WriteLine((@{type=$Type;data=$Data} | ConvertTo-Json -Depth 16 -Compress))
        [Console]::Out.Flush()
    }
}
function Log($Text) { Emit 'log' ((Get-Date -Format 'HH:mm:ss') + '  ' + $Text) }
function Reg($Hive,$Path,$Name,$Value,$Kind='DWord') {
    [pscustomobject]@{Type='Registry';Hive=$Hive;Path=$Path;Name=$Name;Value=$Value;Kind=$Kind}
}
function Service($Name) { [pscustomobject]@{Type='Service';Name=$Name} }
function Task($Path,$Name) { [pscustomobject]@{Type='Task';Path=$Path;Name=$Name} }
function Option($Id,$Category,$Title,$Impact,$Safe,$Targets,$Enterprise=$false) {
    $script:Catalog += [pscustomobject]@{Id=$Id;Category=$Category;Title=$Title;Impact=$Impact;Safe=$Safe;Targets=@($Targets);Enterprise=$Enterprise}
}
$dc='SOFTWARE\Policies\Microsoft\Windows\DataCollection'
$loc='SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors'
$sys='SOFTWARE\Policies\Microsoft\Windows\System'
$cloud='SOFTWARE\Policies\Microsoft\Windows\CloudContent'
$edition = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').EditionID
$enterprise = $edition -match 'Enterprise|Education|IoTEnterprise'
$telemetry = if ($enterprise) {0} else {1}
Option 'diagnostics' 'Diagnostics' 'Minimum diagnostic data' 'Uses the supported minimum for this edition. Pro/Home still send required data; this does not block all Microsoft traffic.' $true @((Reg HKLM $dc AllowTelemetry $telemetry))
Option 'logs' 'Diagnostics' 'Limit diagnostic logs and dumps' 'Restricts additional diagnostic uploads. May reduce information available for Microsoft troubleshooting.' $true @((Reg HKLM $dc LimitDiagnosticLogCollection 1),(Reg HKLM $dc LimitDumpCollection 1))
Option 'device-name' 'Diagnostics' 'Exclude device name' 'Prevents the device name from being included in Windows diagnostic data.' $true @((Reg HKLM $dc AllowDeviceNameInTelemetry 0))
Option 'feedback' 'Diagnostics' 'Stop feedback requests' 'Suppresses Windows feedback notifications.' $true @((Reg HKLM $dc DoNotShowFeedbackNotifications 1))
Option 'ads' 'Personalization' 'Disable advertising ID' 'Disables the Windows advertising ID. Websites and apps may have separate tracking settings.' $true @((Reg HKLM 'SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo' DisabledByGroupPolicy 1),(Reg HKCU 'SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo' Enabled 0))
Option 'tailored' 'Personalization' 'Disable personalized offers' 'Stops Windows diagnostic data being used for tailored suggestions for this user.' $true @((Reg HKCU $cloud DisableTailoredExperiencesWithDiagnosticData 1),(Reg HKCU 'SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy' TailoredExperiencesWithDiagnosticDataEnabled 0))
Option 'typing' 'Personalization' 'Limit typing and handwriting collection' 'Disables typing/inking improvement collection and related personalization consent. Personalized suggestions may be reduced.' $true @((Reg HKLM 'SOFTWARE\Policies\Microsoft\InputPersonalization' RestrictImplicitTextCollection 1),(Reg HKLM 'SOFTWARE\Policies\Microsoft\InputPersonalization' RestrictImplicitInkCollection 1),(Reg HKCU 'SOFTWARE\Microsoft\Input\TIPC' Enabled 0),(Reg HKCU 'SOFTWARE\Microsoft\Personalization\Settings' AcceptedPrivacyPolicy 0))
Option 'launches' 'Personalization' 'Disable app-launch tracking' 'Stops Start/Search learning from app launches. Frequently used app suggestions may change.' $false @((Reg HKCU 'SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' Start_TrackProgs 0))
Option 'languages' 'Personalization' 'Hide language list from websites' 'Disables Windows language-list sharing. Some sites may no longer choose your preferred language automatically.' $false @((Reg HKCU 'Control Panel\International\User Profile' HttpAcceptLanguageOptOut 1))
Option 'activity' 'Activity' 'Stop activity publishing and uploads' 'Disables Windows activity-history publication and uploads where supported. Existing cloud history is not deleted.' $true @((Reg HKLM $sys PublishUserActivities 0),(Reg HKLM $sys UploadUserActivities 0))
Option 'activity-feed' 'Activity' 'Disable activity feed' 'Disables the Windows activity feed where present. Timeline-style experiences may be unavailable.' $false @((Reg HKLM $sys EnableActivityFeed 0))
Option 'location' 'Location' 'Block Windows location access' 'Blocks Windows location services and app access. Automatic time zones, location-based apps and some Wi-Fi scanning may be affected. IP-based location inference remains possible.' $false @((Reg HKLM $loc DisableLocation 1),(Reg HKLM $loc DisableWindowsLocationProvider 1),(Reg HKLM $loc DisableLocationScripting 1),(Reg HKLM 'SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' LetAppsAccessLocation 2),(Reg HKLM 'SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location' Value Deny String),(Reg HKCU 'SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location' Value Deny String))
Option 'find-device' 'Location' 'Disable Find my device' 'Stops Windows Find my device. You will lose its lost-device location capability.' $false @((Reg HKLM 'SOFTWARE\Policies\Microsoft\FindMyDevice' AllowFindMyDevice 0))
Option 'consumer' 'Advanced' 'Disable Microsoft consumer experiences' 'Enterprise/Education policy for promotional suggestions and consumer experiences. Not offered on Pro/Home.' $false @((Reg HKLM $cloud DisableWindowsConsumerFeatures 1)) $true
Option 'ceip' 'Advanced' 'Disable legacy customer-experience program' 'Applies the legacy CEIP opt-out policy. Modern Windows components may use separate diagnostic controls.' $false @((Reg HKLM 'SOFTWARE\Policies\Microsoft\SQMClient\Windows' CEIPEnable 0))
Option 'inventory' 'Advanced' 'Disable application inventory telemetry' 'Disables legacy application inventory/experience policies. Can reduce compatibility information used for troubleshooting and upgrade assessment.' $false @((Reg HKLM 'SOFTWARE\Policies\Microsoft\Windows\AppCompat' AITEnable 0),(Reg HKLM 'SOFTWARE\Policies\Microsoft\Windows\AppCompat' DisableInventory 1))
Option 'diagtrack' 'Advanced' 'Disable Connected User Experiences service' 'Stops and disables DiagTrack. More aggressive than diagnostic policy; reduces diagnostic and managed analytics functionality. Does not guarantee zero telemetry.' $false @((Service DiagTrack))
Option 'mdm' 'Advanced' 'Disable WAP push management service' 'Stops dmwappushservice. Can break Intune/MDM enrollment or synchronization. Avoid on work/school-managed devices.' $false @((Service dmwappushservice))
Option 'compat-tasks' 'Advanced' 'Disable compatibility telemetry tasks' 'Disables Compatibility Appraiser and ProgramDataUpdater if present. May reduce app/upgrade compatibility assessment.' $false @((Task '\Microsoft\Windows\Application Experience\' 'Microsoft Compatibility Appraiser'),(Task '\Microsoft\Windows\Application Experience\' 'ProgramDataUpdater'))
Option 'ceip-tasks' 'Advanced' 'Disable customer-experience tasks' 'Disables Consolidator and UsbCeip if present. Does not disable USB devices.' $false @((Task '\Microsoft\Windows\Customer Experience Improvement Program\' Consolidator),(Task '\Microsoft\Windows\Customer Experience Improvement Program\' UsbCeip))
Option 'feedback-tasks' 'Advanced' 'Disable feedback client tasks' 'Disables the two Windows feedback client scheduled tasks if present.' $false @((Task '\Microsoft\Windows\Feedback\Siuf\' DmClient),(Task '\Microsoft\Windows\Feedback\Siuf\' DmClientOnScenarioDownload))

function Key($Target) { "$($Target.Type)|$($Target.Hive)|$($Target.Path)|$($Target.Name)" }
function Read-State($Target) {
    if ($script:Testing) {
        $k=Key $Target
        if ($script:Mock.ContainsKey($k)) {return $script:Mock[$k]}
        return [pscustomobject]@{Exists=$false;Value=$null;Kind=$null}
    }
    switch ($Target.Type) {
        Registry {
            $root = if ($Target.Hive -eq 'HKLM') {[Microsoft.Win32.Registry]::LocalMachine} else {[Microsoft.Win32.Registry]::CurrentUser}
            $key=$root.OpenSubKey($Target.Path)
            try {
                $exists=($null -ne $key -and $key.GetValueNames() -contains $Target.Name)
                return [pscustomobject]@{Exists=$exists;Value=$(if($exists){$key.GetValue($Target.Name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)}else{$null});Kind=$(if($exists){$key.GetValueKind($Target.Name).ToString()}else{$null})}
            } finally {if($key){$key.Dispose()}}
        }
        Service {
            $svc=@(Get-Service | Where-Object Name -eq $Target.Name)
            if(-not $svc.Count){return [pscustomobject]@{Exists=$false}}
            if ($svc[0].Status.ToString() -notin @('Running','Stopped')) {throw "Service $($Target.Name) is not in a stable running/stopped state."}
            $p=Get-Item ('HKLM:\SYSTEM\CurrentControlSet\Services\'+$Target.Name)
            return [pscustomobject]@{Exists=$true;Start=[int]$p.GetValue('Start');Status=$svc[0].Status.ToString();DelayedExists=($p.GetValueNames() -contains 'DelayedAutoStart');Delayed=$p.GetValue('DelayedAutoStart')}
        }
        Task {
            $task=@(Get-ScheduledTask | Where-Object {$_.TaskPath -eq $Target.Path -and $_.TaskName -eq $Target.Name})
            if(-not $task.Count){return [pscustomobject]@{Exists=$false}}
            return [pscustomobject]@{Exists=$true;Enabled=[bool]$task[0].Settings.Enabled}
        }
    }
}
function Desired($Target) {
    switch($Target.Type) {
        Registry {return [pscustomobject]@{Exists=$true;Value=$Target.Value;Kind=$Target.Kind}}
        Service {return [pscustomobject]@{Exists=$true;Start=4;Status='Stopped';DelayedExists=$false;Delayed=$null}}
        Task {return [pscustomobject]@{Exists=$true;Enabled=$false}}
    }
}
function Matches($Target,$Actual,$Expected,[switch]$Exact) {
    if($Actual.Exists -ne $Expected.Exists){return $false}
    if(-not $Actual.Exists){return $true}
    switch($Target.Type) {
        Registry {return ($Actual.Kind -eq $Expected.Kind -and (ConvertTo-Json -InputObject $Actual.Value -Compress) -ceq (ConvertTo-Json -InputObject $Expected.Value -Compress))}
        Service {return ($Actual.Start -eq $Expected.Start -and $Actual.Status -eq $Expected.Status -and (-not $Exact -or ($Actual.DelayedExists -eq $Expected.DelayedExists -and $Actual.Delayed -eq $Expected.Delayed)))}
        Task {return ($Actual.Enabled -eq $Expected.Enabled)}
    }
}
function Write-State($Target,$State) {
    if($script:Testing) {
        if((Key $Target) -eq $script:FailWrite){throw 'Simulated write failure'}
        $script:Mock[(Key $Target)]=$State
        return
    }
    switch($Target.Type) {
        Registry {
            $root=if($Target.Hive -eq 'HKLM'){[Microsoft.Win32.Registry]::LocalMachine}else{[Microsoft.Win32.Registry]::CurrentUser}
            $key=if($State.Exists){$root.CreateSubKey($Target.Path)}else{$root.OpenSubKey($Target.Path,$true)}
            try {
                if($State.Exists){$key.SetValue($Target.Name,$State.Value,[Microsoft.Win32.RegistryValueKind]$State.Kind)}
                elseif($key){$key.DeleteValue($Target.Name,$false)}
            } finally {if($key){$key.Dispose()}}
        }
        Service {
            if(-not $State.Exists){throw 'Cannot recreate or delete services.'}
            $startup=switch([int]$State.Start){2{'Automatic'} 3{'Manual'} 4{'Disabled'} default{throw 'Unsupported service startup mode'}}
            if($State.Status -eq 'Stopped') { Stop-Service -Name $Target.Name -ErrorAction Stop }
            Set-Service -Name $Target.Name -StartupType $startup
            $key=[Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(('SYSTEM\CurrentControlSet\Services\'+$Target.Name),$true)
            try {
                if($State.DelayedExists){$key.SetValue('DelayedAutoStart',[int]$State.Delayed,[Microsoft.Win32.RegistryValueKind]::DWord)}
                else{$key.DeleteValue('DelayedAutoStart',$false)}
            } finally {$key.Dispose()}
            if($State.Status -eq 'Running') {
                if($State.Start -eq 4){
                    Set-Service -Name $Target.Name -StartupType Manual
                    try{Start-Service -Name $Target.Name}finally{Set-Service -Name $Target.Name -StartupType Disabled}
                } else {Start-Service -Name $Target.Name}
            }
            (Get-Service -Name $Target.Name).WaitForStatus([System.ServiceProcess.ServiceControllerStatus]$State.Status,[TimeSpan]::FromSeconds(20))
        }
        Task {
            if(-not $State.Exists){throw 'Cannot recreate or delete tasks.'}
            if($State.Enabled){Enable-ScheduledTask -TaskPath $Target.Path -TaskName $Target.Name | Out-Null}
            else{Disable-ScheduledTask -TaskPath $Target.Path -TaskName $Target.Name | Out-Null}
        }
    }
}
function Identity {
    if($script:Testing){return 'TEST-USER'}
    return [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
}
function Machine {
    if($script:Testing){return 'TEST-MACHINE'}
    return (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Cryptography').MachineGuid
}
function Save-Snapshot($Snapshot) {
    if($Snapshot.Id -notmatch '^\d{8}-\d{6}-[a-f0-9]{8}$'){throw 'Invalid snapshot identifier.'}
    $dir=Join-Path $DataRoot 'Snapshots'
    [IO.Directory]::CreateDirectory($dir) | Out-Null
    $file=Join-Path $dir ($Snapshot.Id+'.clixml')
    $tmp=$file+'.tmp'
    $Snapshot | Export-Clixml -LiteralPath $tmp -Depth 20
    if(Test-Path -LiteralPath $file){[IO.File]::Replace($tmp,$file,($file+'.previous'))}else{[IO.File]::Move($tmp,$file)}
}
function Selected {
    $requested=@($Ids.Split(',') | Where-Object {$_})
    if(-not $requested.Count){throw 'Select at least one control.'}
    foreach($id in $requested){if(-not @($script:Catalog | Where-Object Id -eq $id).Count){throw "Unknown control: $id"}}
    $selected=@($script:Catalog | Where-Object {$requested -contains $_.Id})
    foreach($c in $selected){if($c.Enterprise -and -not $enterprise){throw "$($c.Title) is not supported on this edition."}}
    return $selected
}
function Capture($Controls) {
    $entries=@()
    foreach($c in $Controls) {
        foreach($t in $c.Targets) {
            $s=Read-State $t
            if($t.Type -ne 'Registry' -and -not $s.Exists){Log "Not present; skipped: $($t.Name)";continue}
            $entries += [pscustomobject]@{Control=$c.Id;Title=$c.Title;Target=$t;Before=$s;After=(Desired $t);Attempted=$false;Restored=$false}
        }
    }
    if(-not $entries.Count){throw 'None of the selected targets exist on this computer.'}
    $snapshot=[pscustomobject]@{Version=1;Id=((Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8));Created=(Get-Date).ToString('o');Machine=(Machine);User=(Identity);Status='Snapshot only';Entries=$entries;Error=''}
    Save-Snapshot $snapshot
    Log "Snapshot saved before any change: $($snapshot.Id) ($($entries.Count) targets)."
    return $snapshot
}
function Apply-Snapshot($Snapshot) {
    try {
        $Snapshot.Status='Applying'; Save-Snapshot $Snapshot
        foreach($e in $Snapshot.Entries) {
            $now=Read-State $e.Target
            if(-not (Matches $e.Target $now $e.Before -Exact)){throw "State changed after snapshot: $($e.Target.Name). Scan and try again."}
            if(Matches $e.Target $now $e.After){Log "Already configured: $($e.Title) / $($e.Target.Name)";continue}
            $e.Attempted=$true; Save-Snapshot $Snapshot
            Log "Applying: $($e.Title) / $($e.Target.Name)"
            Write-State $e.Target $e.After
            if(-not (Matches $e.Target (Read-State $e.Target) $e.After)){throw "Read-back verification failed: $($e.Target.Name)"}
            Log "Verified: $($e.Target.Name)"
        }
        $Snapshot.Status='Applied';Save-Snapshot $Snapshot
    } catch {
        $Snapshot.Status='Partial / failed';$Snapshot.Error=$_.Exception.Message;Save-Snapshot $Snapshot
        Log 'Stopped on error. The snapshot includes every attempted target; use Restore to undo this run.'
        throw
    }
}
function Restore-Snapshot($Snapshot) {
    if($Snapshot.Version -ne 1 -or $Snapshot.Machine -ne (Machine) -or $Snapshot.User -ne (Identity)){throw 'Snapshot belongs to a different machine/user or an unsupported version.'}
    # Validate all target addresses against the built-in catalog before writing.
    $allowed=@{}
    foreach($c in $script:Catalog){foreach($t in $c.Targets){$allowed[(Key $t)]=$true}}
    foreach($e in $Snapshot.Entries){if(-not $allowed.ContainsKey((Key $e.Target))){throw 'Snapshot contains a target outside the built-in catalog.'}}
    if($Snapshot.Status -eq 'Snapshot only'){throw 'This is a preview snapshot. No changes were applied, so there is nothing to undo.'}
    $errors=@()
    $entries=@($Snapshot.Entries);[array]::Reverse($entries)
    foreach($e in $entries) {
        if(-not $e.Attempted -or $e.Restored){continue}
        try {
            Log "Restoring: $($e.Title) / $($e.Target.Name)"
            Write-State $e.Target $e.Before
            if(-not (Matches $e.Target (Read-State $e.Target) $e.Before -Exact)){throw 'Restore read-back verification failed.'}
            $e.Restored=$true;Save-Snapshot $Snapshot
            Log "Restored and verified: $($e.Target.Name)"
        } catch {$errors += "$($e.Target.Name): $($_.Exception.Message)";Log $errors[-1]}
    }
    if($errors.Count){$Snapshot.Status='Restore incomplete';$Snapshot.Error=$errors -join '; '}
    else{$Snapshot.Status='Restored';$Snapshot.Error=''}
    Save-Snapshot $Snapshot
    if($errors.Count){throw $Snapshot.Error}
}
function Describe-State($Target,$State) {
    if(-not $State.Exists){if($Target.Type -eq 'Registry'){return 'Not set (Windows default)'}else{return 'Not installed'}}
    switch($Target.Type) {
        Registry {return ((ConvertTo-Json -InputObject $State.Value -Compress)+' ('+$State.Kind+')')}
        Service {
            $start=switch([int]$State.Start){2{'Automatic'} 3{'Manual'} 4{'Disabled'} default{'Other'}}
            if($State.DelayedExists -and $State.Delayed -eq 1 -and $State.Start -eq 2){$start+=' (delayed)'}
            return ($State.Status+'; '+$start)
        }
        Task {if($State.Enabled){return 'Enabled'}else{return 'Disabled'}}
    }
}
function Audit {
    $rows=@()
    foreach($c in $script:Catalog) {
        $details=@();$set=0;$available=0;$errorText=''
        $unsupported=$c.Enterprise -and -not $enterprise
        foreach($t in $c.Targets) {
            $want=Desired $t
            $expected=Describe-State $t $want
            $address=if($t.Type -eq 'Registry'){$t.Hive+'\'+$t.Path+'\'+$t.Name}elseif($t.Type -eq 'Task'){$t.Path+$t.Name}else{$t.Name}
            try {
                $state=Read-State $t
                $current=Describe-State $t $state
                $missing=$t.Type -ne 'Registry' -and -not $state.Exists
                if(-not $missing){$available++;if(Matches $t $state $want){$set++}}
                $targetStatus=if($unsupported){'Unsupported edition'}elseif($missing){'Not installed'}elseif(Matches $t $state $want){'Done'}else{'Not done'}
                $details += ($t.Name+': '+$current+' -> '+$expected+' ['+$targetStatus+']')
            } catch {$errorText=$_.Exception.Message;$current='Unknown: '+$errorText;$targetStatus='Unknown';$details += ($t.Name+': '+$current)}
            Emit 'target' @{Control=$c.Title;ControlId=$c.Id;Category=$c.Category;Target=$t.Name;Address=$address;Status=$targetStatus;Current=$current;Desired=$expected}
        }
        $status=if($unsupported){'Unsupported edition'}elseif($errorText){'Unknown'}elseif(-not $available){'Not installed'}elseif($set -eq $available){'Configured'}elseif($set){'Partial'}else{'Not configured'}
        $row=[pscustomobject]@{Id=$c.Id;Category=$c.Category;Title=$c.Title;Impact=$c.Impact;Safe=$c.Safe;Status=$status;Details=($details -join "`n");Available=($status -notin @('Unsupported edition','Not installed','Unknown'))}
        $rows+=$row;Emit 'control' $row
    }
    $checks=@()
    try {
        $m=Get-MpComputerStatus
        $checks+=@{Name='Defender antivirus';State=$(if($m.AntivirusEnabled){'Enabled'}else{'Disabled'})}
        $checks+=@{Name='Real-time protection';State=$(if($m.RealTimeProtectionEnabled){'Enabled'}else{'Disabled'})}
        $checks+=@{Name='Tamper protection';State=$(if($m.IsTamperProtected){'Enabled'}else{'Disabled'})}
    } catch {$checks+=@{Name='Microsoft Defender';State='Unknown: '+$_.Exception.Message}}
    try {foreach($p in Get-NetFirewallProfile){$checks+=@{Name=($p.Name+' firewall');State=$(if($p.Enabled){'Enabled'}else{'Disabled'})}}}catch{$checks+=@{Name='Firewall';State='Unknown: '+$_.Exception.Message}}
    try {$s=Get-Service wuauserv;$checks+=@{Name='Windows Update service';State=($s.Status.ToString()+' / '+$s.StartType.ToString()+' (not an update-compliance check)')}}catch{$checks+=@{Name='Windows Update';State='Unknown'}}
    try {$secure=Confirm-SecureBootUEFI;$checks+=@{Name='Secure Boot';State=$(if($secure){'Enabled'}else{'Disabled'})}}catch{$checks+=@{Name='Secure Boot';State='Unavailable / not supported'}}
    try {$b=Get-BitLockerVolume -MountPoint $env:SystemDrive;$checks+=@{Name='System drive encryption';State=($b.VolumeStatus.ToString()+' / protection '+$b.ProtectionStatus.ToString())}}catch{$checks+=@{Name='System drive encryption';State='Unknown / unavailable'}}
    $os=Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    Emit 'audit' @{Edition=$edition;Build=$os.CurrentBuild;Version=$os.DisplayVersion;Configured=@($rows|Where-Object Status -eq 'Configured').Count;Total=$rows.Count;Checks=$checks;Time=(Get-Date).ToString('o')}
    Log 'Audit complete. Configuration read-back is not a network traffic test. Security checks are read-only.'
}
function List-Snapshots {
    $dir=Join-Path $DataRoot 'Snapshots';$list=@()
    if(Test-Path $dir){foreach($file in Get-ChildItem $dir -Filter '*.clixml' | Sort-Object Name -Descending){
        try{$s=Import-Clixml -LiteralPath $file.FullName;$list+=@{Id=$s.Id;Created=$s.Created;Status=$s.Status;Count=@($s.Entries).Count;Error=$s.Error}}catch{Log "Unreadable snapshot: $($file.Name)"}
    }}
    Emit 'snapshots' @($list)
}
function Self-Test {
    function Assert($Condition,$Message){if(-not $Condition){throw "TEST FAILED: $Message"}}
    $DataRoot=Join-Path $DataRoot ('test-'+[Guid]::NewGuid().ToString('N'))
    $script:DataRoot=$DataRoot
    $a=Reg HKCU 'Test' A 0
    $b=Reg HKCU 'Test' B 1
    $svc=Service TestService
    $task=Task '\Test\' TestTask
    $original=[pscustomobject]@{Exists=$true;Value='%PATH%';Kind='ExpandString'}
    $originalService=[pscustomobject]@{Exists=$true;Start=2;Status='Running';DelayedExists=$true;Delayed=1}
    $originalTask=[pscustomobject]@{Exists=$true;Enabled=$false}
    $script:Mock[(Key $a)]=$original
    $script:Mock[(Key $svc)]=$originalService
    $script:Mock[(Key $task)]=$originalTask
    $control=[pscustomobject]@{Id='test';Title='Test';Targets=@($a,$b,$svc,$task)}
    $script:Catalog+= $control
    $snapshot=Capture @($control)
    Assert (Test-Path (Join-Path $DataRoot ('Snapshots\'+$snapshot.Id+'.clixml'))) 'snapshot must exist before writes'
    Assert (Matches $a (Read-State $a) $original -Exact) 'capture must be read-only'
    Apply-Snapshot $snapshot
    Assert ($snapshot.Status -eq 'Applied') 'apply succeeds'
    Assert (-not $snapshot.Entries[3].Attempted) 'already disabled task must not be changed'
    Restore-Snapshot $snapshot
    Assert (Matches $a (Read-State $a) $original -Exact) 'registry type and raw data restored'
    Assert (-not (Read-State $b).Exists) 'originally absent value removed'
    Assert (Matches $svc (Read-State $svc) $originalService -Exact) 'service status and delayed start restored'
    Assert (Matches $task (Read-State $task) $originalTask -Exact) 'disabled task stays disabled'
    $snapshot2=Capture @($control)
    $script:FailWrite=Key $b
    try{Apply-Snapshot $snapshot2;throw 'Failure injection did not fire'}catch{Assert ($snapshot2.Status -eq 'Partial / failed') 'partial failure is journaled'}
    $script:FailWrite=''
    Restore-Snapshot $snapshot2
    Assert (Matches $a (Read-State $a) $original -Exact) 'partial apply can be restored'
    $snapshot3=Capture @($control);$snapshot3.Machine='other'
    try{Restore-Snapshot $snapshot3;throw 'identity guard failed'}catch{Assert ($_.Exception.Message -match 'different machine') 'cross-machine restore rejected'}
    # Serialize round trip, including raw registry types.
    $round=Import-Clixml (Join-Path $DataRoot ('Snapshots\'+$snapshot.Id+'.clixml'))
    Assert ($round.Entries[0].Before.Kind -eq 'ExpandString') 'backup serialization preserves kinds'
    $snapshot4=Capture @($control)
    $script:Mock[(Key $a)]=[pscustomobject]@{Exists=$true;Value=999;Kind='DWord'}
    try{Apply-Snapshot $snapshot4;throw 'state guard did not fire'}catch{Assert ($_.Exception.Message -match 'State changed after snapshot') 'concurrent state changes stop application'}
    Assert (-not $snapshot4.Entries[0].Attempted) 'changed state is not overwritten'
    $script:Mock[(Key $a)]=$original
    $snapshot5=Capture @($control);Apply-Snapshot $snapshot5
    $script:FailWrite=Key $a
    try{Restore-Snapshot $snapshot5;throw 'restore failure did not fire'}catch{Assert ($snapshot5.Status -eq 'Restore incomplete') 'restore errors are reported'}
    $script:FailWrite='';Restore-Snapshot $snapshot5
    Assert ($snapshot5.Status -eq 'Restored') 'incomplete restores can be retried'
    $snapshot6=Capture @($control);$snapshot6.Status='Applied';$snapshot6.Entries[0].Target=Reg HKCU 'OutsideCatalog' Inject 1
    try{Restore-Snapshot $snapshot6;throw 'target validation did not fire'}catch{Assert ($_.Exception.Message -match 'outside the built-in catalog') 'noncatalog targets rejected'}
    [Console]::Out.WriteLine('PASS: capture-only, snapshot-before-write, apply, exact restore, absent values, delayed services, disabled tasks, partial failure recovery, identity validation, serialization, concurrent-state guard, restore retry, snapshot target validation. No system changes made.')
    [Console]::Out.WriteLine('Test artifacts: '+$DataRoot)
}
try {
    if($Mode -eq 'SelfTest'){Self-Test;exit 0}
    if($Mode -in @('Apply','Snapshot','Restore')) {
        if(-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Administrator access is required.'}
    }
    switch($Mode) {
        Audit {Log 'Reading Windows privacy policies, services, tasks and security status...';Audit}
        Snapshot {$s=Capture @(Selected);Emit 'result' @{Message='Snapshot saved; no system settings changed.';Snapshot=$s.Id};List-Snapshots}
        Apply {$s=Capture @(Selected);Apply-Snapshot $s;Emit 'result' @{Message='Selected changes applied and read-back verified. Restart when convenient.';Snapshot=$s.Id};List-Snapshots}
        Restore {
            if($SnapshotId -notmatch '^\d{8}-\d{6}-[a-f0-9]{8}$'){throw 'Invalid snapshot identifier.'}
            $s=Import-Clixml -LiteralPath (Join-Path $DataRoot ('Snapshots\'+$SnapshotId+'.clixml'))
            if($s.Id -ne $SnapshotId){throw 'Snapshot identifier does not match its filename.'}
            Restore-Snapshot $s;Emit 'result' @{Message='Snapshot restored and read-back verified. Restart when convenient.';Snapshot=$s.Id};List-Snapshots
        }
        List {List-Snapshots}
    }
    exit 0
} catch {Emit 'error' $_.Exception.Message;if($script:Testing){[Console]::Error.WriteLine($_.Exception.ToString())};exit 1}
