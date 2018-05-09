<#
    .DESCRIPTION
        This script lists the virtual machines which created between a specific duration
    .NOTES
        AUTHOR: Shibin Subhash
        LASTEDIT: May 4, 2018
#>
Param(
    [Parameter(Mandatory=$true)]
	[string]$StartTime,			

    [Parameter(Mandatory=$true)]
	[string]$EndTime
	
	#StartTime and EndTime should be in the format yyyy-mm-ddThh:mm, Eg: 2018-04-14T10:30
)

#Fetch the resource ids of all virtual machines
$VMResIds = Get-AzureRmResource | Where-Object { $_.ResourceType -eq "Microsoft.Compute/virtualMachines"} | Select-Object ResourceId

#Get logs related to creation of virtual machines during the given time period
$Logs = Get-AzureRmLog `
		-ResourceProvider Microsoft.compute `
		-DetailedOutput `
        -MaxEvents 100000 `
        -StartTime $StartTime `
        -EndTime $EndTime `
        | Where-Object { $_.Authorization.Action -and $_.Properties.Content } `
        | Where-Object { $_.Authorization.Action -eq "Microsoft.Compute/virtualMachines/write" -and $_.Properties.Content["statusCode"] -eq "Created" } `
        | Sort-Object -Property EventTimestamp `
        | Select-Object ResourceId, EventTimestamp

#Write virtual machine name and created time into an array 
$List = New-Object System.Collections.ArrayList
foreach($Log in $Logs) {
    $VMResId = $Log.ResourceId
    $CreatedTime = $Log.EventTimestamp 
    if ($VMResIds.ResourceId -contains $VMResId) {
		$VMname = (Get-AzureRmResource -ResourceId $VMResId).ResourceName
        $List.Add((New-Object PSObject -Property @{ VirtualMachine = $VMname; CreatedOn = $CreatedTime })) | Out-Null
    }
}

$List | Sort-Object VirtualMachine