<#
    .DESCRIPTION
        This Script calculates the no. of days each resource active in the subscription based on CreatedOn tag.
    .NOTES
        AUTHOR: Shibin Subhash
        LASTEDIT: Mar 16, 2018
#>

#Resource group data
$taggedRGs = (Find-AzureRmResourceGroup -Tag @{ CreatedOn = $null }).Name
$RGdata = New-Object System.Collections.ArrayList
foreach ($rg in $taggedRGs){ 
	$CreatedOn = (Get-AzureRmResourceGroup -Name $rg).tags.CreatedOn
	$CreatedBy = (Get-AzureRmResourceGroup -Name $rg).tags.CreatedBy	
	$dayCount = (New-TimeSpan -Start $CreatedOn).Days
	$RGdata.Add((New-Object PSObject -Property @{ResourceGroupName = $rg; CreatedOn = $CreatedOn; CreatedBy = $CreatedBy; Days = $dayCount})) | Out-Null
}
$RGdata | Sort-Object -property "Days" -Descending | Export-Csv "C:\Users\c001447\Desktop\RGdata.csv"

#Resources data
$taggedRes = (Find-AzureRmResource -Tag @{ CreatedBy = $null; CreatedOn = $null }).ResourceId
$ResData = New-Object System.Collections.ArrayList
foreach ($resId in $taggedRes){
	$CreatedOn = (Get-AzureRmResource -ResourceId $resId).tags.CreatedOn
	$CreatedBy = (Get-AzureRmResource -ResourceId $resId).tags.CreatedBy
	$resName = (Get-AzureRmResource -ResourceId $resId).ResourceName
	$dayCount = (New-TimeSpan -Start $CreatedOn).Days
	$ResData.Add((New-Object PSObject -Property @{ResourceName = $resName; ResourceId = $resId; CreatedOn = $CreatedOn; CreatedBy = $CreatedBy; Days = $dayCount})) | Out-Null
}
$ResData | Sort-Object -property "Days" -Descending | Export-Csv "C:\Users\c001447\Desktop\ResData.csv"