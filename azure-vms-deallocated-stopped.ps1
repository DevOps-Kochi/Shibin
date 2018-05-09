<#
    .DESCRIPTION
        This Script lists the deallocated VMs and the duration of stopped state.
    .NOTES
        AUTHOR: Shibin Subhash
        LASTEDIT: May 2, 2018
#>
Param(
    [Parameter(Mandatory=$true)] 
	[ValidateRange(0, 89)] 
	[int32]$Age
)
#Gets the deallocated VMs details
$StoppedVMs = get-azurermvm -Status | Where-Object PowerState -In "VM deallocated", "VM stopped"

#Calcluating the number of days
$List = New-Object System.Collections.ArrayList
foreach ($VM in $StoppedVMs){
	$RGname = $VM.ResourceGroupName
	$VMname = $VM.Name
	$StoppedAt = (Get-AzureRmVM -ResourceGroupName $RGname -Name $VMname -Status).Statuses.time
    $DayCount = (New-TimeSpan -Start $StoppedAt[0]).Days
	$List.Add((New-Object PSObject -Property @{VirtualMachine = $VMname; ResourceGroup = $RGname; Days = $DayCount})) | Out-Null
}

#Lists the deallocated/stopped VMs which is stopped for more than $Age days
$List | Where-Object { $_.Days -gt $Age } | Sort-Object Days