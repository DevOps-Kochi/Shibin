<#
    .DESCRIPTION
        This Script tags all ARM resource groups and resources with created date(CreatedOn) and created id(CreatedBy).
    .NOTES
        AUTHOR: Shibin Subhash
        LASTEDIT: Mar 15, 2018
#>
Param(
    [Parameter()]
    [ValidateRange(1, 90)] 
    [int32]$DayCount = 90
)

$days = $DayCount * -1

$connectionName = "AzureRunAsConnection"

# the subscription ID of the Azure subscription 
$SubscriptionId = Get-AutomationVariable -Name "SubscriptionId"

try {
    # Get the connection "AzureRunAsConnection"
    $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName         
    
    Write-Verbose "Logging in to Azure..."
    Add-AzureRmAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint | Out-Null
    
    #Switch to the subscription       
    Set-AzureRmContext -SubscriptionId $SubscriptionId | Out-Null
}
catch {
    if (!$servicePrincipalConnection) {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    }
    else {
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

#_______________________________Tagging the Resource groups________________________________________
$allRGs = (Get-AzureRmResourceGroup).ResourceGroupName
Write-Warning "Found $($allRGs.Length) total RGs"

$taggedRGs = (Find-AzureRmResourceGroup -Tag @{ CreatedBy = $null; CreatedOn = $null }).Name
Write-Warning "Found $($taggedRGs.Length) tagged RGs"

$unTaggedRGs = $allRGs | ? {-not ($taggedRGs -contains $_)}
Write-Warning "Found $($unTaggedRGs.Length) un-tagged RGs"

$newlyTaggedRGs = New-Object System.Collections.ArrayList

foreach ($rg in $unTaggedRGs) {
    
    $RGLogs = Get-AzureRmLog -ResourceGroup $rg -DetailedOutput `
        -MaxEvents 70000 `
        -StartTime (Get-Date).AddDays($days) `
        -EndTime (Get-Date)`
        | ? {$_.Caller -and $_.Properties.Content} `
        | Where-Object { $_.Caller -and $_.Properties.Content["statusCode"] -eq "Created" } `
        | Sort-Object -Property EventTimestamp  `
        | Select-Object ResourceId, Caller, EventTimestamp

    if ($RGLogs) {
        $createdBy = $RGLogs[0].Caller
        $createdOn = $RGLogs[0].EventTimestamp
				
        Write-Warning "Tagging Resource Group $rg with CreatedOn $CreatedOn and CreatedBy $CreatedBy"      

        Set-AzureRmResourceGroup -Name $rg -Tag @{ CreatedOn = $createdOn; CreatedBy = $createdBy} | Out-Null

        $newlyTaggedRGs.Add((New-Object PSObject -Property @{ResourceGroupName = $rg; CreatedOn = $createdOn; CreatedBy = $createdBy})) | Out-Null
        
    }
    else {
        Write-Warning "No activity found for Resource Group $rg"
    }
}

Write-Host "Searching Resource Group logs completed" -ForegroundColor Yellow


#_______________________________Tagging other Resources than Resource groups________________________________________
$allRes = (Get-AzureRmResource).ResourceId
Write-Host "Found $($allRes.Count) total resources" -ForegroundColor Yellow

$taggedRes = (Find-AzureRmResource -Tag @{ CreatedBy = $null; CreatedOn = $null }).ResourceId
Write-Host "Found $($taggedRes.Count) tagged resources" -ForegroundColor Yellow

$unTaggedRes = $allRes | ? {-not ($taggedRes -contains $_)}
Write-Host "Found $($unTaggedRes.Count) un-tagged Resources" -ForegroundColor Yellow

$newlyTaggedRes = New-Object System.Collections.ArrayList

foreach ($res in $unTaggedRes){

    $ResLogs = Get-AzureRmLog -ResourceId $res -DetailedOutput `
        -MaxEvents 70000 `
        -StartTime (Get-Date).AddDays($days) `
        -EndTime (Get-Date) `
        | ? {$_.Caller -and $_.Properties.Content} `
        | Where-Object { $_.Properties.Content["statusCode"] -eq "Created" -or $_.Properties.Content["statusMessage"] -eq """Resource provisioning is in progress.""" }`
        | Sort-Object -Property EventTimestamp  `
        | Select-Object ResourceId, Caller, EventTimestamp

    if ($ResLogs) 
    {
        $CreatedBy = $ResLogs[0].Caller
        $CreatedOn = $ResLogs[0].EventTimestamp
        $resId = $ResLogs[0].ResourceId
        $resName = (Get-AzureRmResource -ResourceId $resId).ResourceName                             
        
        Write-Warning "Tagging Resource $resName for CreatedOn $CreatedOn and CreatedBy $CreatedBy"

        Set-AzureRmResource -Force -ResourceId $resId -Tag @{ CreatedOn = $CreatedOn; CreatedBy = $CreatedBy } | Out-Null
        
        $newlyTaggedRes.Add((New-Object PSObject -Property @{ ResourceName = $resName; CreatedOn = $CreatedOn; CreatedBy = $CreatedBy})) | Out-Null
    }                                             
    else 
    {
     Write-Warning "No activity found for Resource $res"
    }
}

Write-Host "`nSearching Resource's logs completed" -ForegroundColor Yellow

Write-Host "`nNewly tagged Resource Groups are...." -ForegroundColor Yellow
$newlyTaggedRGs | ft ResourceGroupName, CreatedOn, CreatedBy
$result1 = $newlyTaggedRGs | ft ResourceGroupName, CreatedOn, CreatedBy

Write-Warning "Newly tagged Resource Groups $result1"


Write-Host "`nNewly tagged Resources are...." -ForegroundColor Yellow
$newlyTaggedRes | ft ResourceName, CreatedOn, CreatedBy
$result2 = $newlyTaggedRes | ft ResourceName, CreatedOn, CreatedBy

Write-Warning "Newly tagged Resources $result2"

