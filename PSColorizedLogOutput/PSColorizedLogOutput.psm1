
class LogLevel {
      [String] $Name
      [Collections.Generic.List[String]] $AlternativeNames;
      [System.ConsoleColor] $Color

      static [LogLevel] $TRACE = [LogLevel]::new("TRACE", (" TRACE ", " Trace ", " T "), [System.ConsoleColor]::DarkYellow)
      static [LogLevel] $DEBUG = [LogLevel]::new("DEBUG", (" DEBUG ", " Debug ", " D "), [System.ConsoleColor]::DarkCyan)
      static [LogLevel] $INFO =  [LogLevel]::new("INFO",  (" INFO " , " Info " , " I "), [System.ConsoleColor]::White)
      static [LogLevel] $WARN =  [LogLevel]::new("WARN",  (" WARN " , " Warn " , " W "), [System.ConsoleColor]::Yellow)
      static [LogLevel] $ERROR = [LogLevel]::new("ERROR", (" ERROR ", " Error ", " E "), [System.ConsoleColor]::DarkRed)
      static [LogLevel] $FATAL = [LogLevel]::new("FATAL", (" FATAL ", " Fatal ", " F "), [System.ConsoleColor]::Red)

      LogLevel([String] $Name){
        $this.Name = $Name
      }

      LogLevel([String] $Name, [Collections.Generic.List[String]] $AlternativeNames){
        $this.Name = $Name
        $this.AlternativeNames = $AlternativeNames
      }

      LogLevel([String] $Name, [Collections.Generic.List[String]] $AlternativeNames, [System.ConsoleColor] $Color){
        $this.Name = $Name
        $this.AlternativeNames = $AlternativeNames
        $this.Color = $Color
      }

      [bool] Equals([System.Object] $other) {
        if($other -eq $null) {
            return $false;
        }

        if($other.GetType() -eq $this.GetType()){
            return ($this.Name -eq $other.Name)
        } else {
            return $false
        }
      }

      [int] GetHashCode(){
        [int] $hash = 13
        return ($hash * 7) + $this.Name.GetHashCode()
      }
}



<# 
 .Synopsis
  Reads a string and writes it to host with the color of the detected LogLevel

 .Description
  Reads a string and writes it to host with the color of the detected LogLevel as the foreground color.
  All the AlternativeNames of a LogLevel will be used to analyse a line. 
  The specific ConsoleColor of a LogLevel can be changed before using this function.

 .Parameter Line
  Specifies the line that should be written to host with the specific foreground color of the detected LogLevel

 .Parameter Line
  Specifies the line that should be written to host with the specific foreground color of the detected LogLevel

 .Example
   Get-Content C:\wildfly-10.1.0.Final\standalone\log\server.log | Write-HostWithColorizedLogLevels

 .Example
   # you can also tail the logfile and pipe it to this function
   Get-Content C:\wildfly-10.1.0.Final\standalone\log\server.log -Tail 10 -Wait | Write-HostWithColorizedLogLevels

 .Example
   # you want only see parts of the logfile that represents specific loglevel?
   # In this example only the LogLevels WARN and ERROR are written to host. Other Levels will not be shown
   Get-Content C:\wildfly-10.1.0.Final\standalone\log\server.log | Write-HostWithColorizedLogLevels -ShowOnly WARN, ERROR
#>
function Write-HostWithColorizedLogLevels {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false, ValueFromPipeline=$true)]
        [string[]]$Line,
        [Parameter(Mandatory=$false, ValueFromPipeline=$false)]
        [ValidateNotNull()]
        [ValidateSet("TRACE", "DEBUG", "INFO", "WARN", "ERROR", "FATAL")]
        [String[]] $ShowOnly = @()
    )

    BEGIN {
        [LogLevel] $lastDetectedLevel = $null;
        [System.ConsoleColor] $DefaultHostForegroundColor = (Get-Host).UI.RawUI.ForegroundColor
        [LogLevel[]]$LogLevels = ([LogLevel]::TRACE, [LogLevel]::DEBUG, [LogLevel]::INFO, [LogLevel]::WARN, [LogLevel]::ERROR, [LogLevel]::FATAL)
    }

    PROCESS {
        # if there is no string data to analyse then we must not iterate over LogLevels and all these stuff
        if($Line -eq $null) { return }
        if($Line.Length -eq 0) { Write-Host $Line}

        $levelMatched = $false;
        $LogLevels | % {
            if(!$levelMatched) {
                $currentLogLevel = $_
                if($_.AlternativeNames -ne $null -or $_.AlternativeNames.Count -ne 0){
                    $_.AlternativeNames | % {
                        if(!$levelMatched) {
                            if($Line -clike "*$($_)*"){
                                $levelMatched = $true
                                $lastDetectedLevel = $currentLogLevel
                                if($ShowOnly.Count -eq 0){
                                    Write-Host $Line -ForegroundColor $currentLogLevel.Color
                                } else {
                                    if($ShowOnly -contains $currentLogLevel.Name) {
                                        Write-Host $Line -ForegroundColor $currentLogLevel.Color
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        # if no level could be detected for a line, but a level was already detected 
        # we assume that it has the same like the last level that was detected
        if(!$levelMatched -and $lastDetectedLevel -ne $null -and $ShowOnly -contains $lastDetectedLevel.Name) {
            Write-Host $Line -ForegroundColor $lastDetectedLevel.Color 
         } else {
            if(!$levelMatched -and $ShowOnly.Count -eq 0) {
                # maybe the first lines we got did not match a LogLevel then we set the ForegroundColor that
                # was set before the function has started
                Write-Host $Line -ForegroundColor $DefaultHostForegroundColor
            }
         }
    }

    END {
        # set the ForegroundColor to the color that was set before the function started
        (Get-Host).UI.RawUI.ForegroundColor = $DefaultHostForegroundColor
    }
}

function Test-LogLevelFromLine {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
        [string[]]$Line,
        [Parameter(Mandatory=$true, Position=1, ValueFromPipeline=$false)]
        [LogLevel] $Level 
    )

    PROCESS {
        $currentLine = $_
        if($Level.AlternativeNames -ne $null -or $Level.AlternativeNames.Count -ne 0){
            @($Level.AlternativeNames | % {
                $currentLine -clike "*$($_)*"
            }) -contains $true
        } else {
            return $false
        }

    }
}

Export-ModuleMember -Function Write-HostWithColorizedLogLevels
Export-ModuleMember -Function Test-LogLevelFromLine

