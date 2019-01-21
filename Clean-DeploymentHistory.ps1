Set-StrictMode -Version latest
$ErrorActionPreference = "Stop"

function Get-Deployments
{
  param(
      [int]
      [ValidateRange(10,800)] 
      $SkipLast = 10,
      [Parameter(Mandatory)]
      [string]$ResourceGroupName
    )
   
    $deployments = @((Get-AzureRmResourceGroupDeployment $($resourceGroupName) | Sort-Object -Property timestamp ) | Select-Object -SkipLast ($SkipLast))    
    return $deployments 
}

function Remove-Deployments
{
    [cmdletbinding(SupportsShouldProcess=$True)]
    param (
        [array]
        $Deployments,
        [Parameter(Mandatory)]
        [string]$ResourceGroupName
    )

    $Deployments  | ForEach-Object {
        if (!([string]::IsNullOrWhiteSpace(($_.DeploymentName))))
        {
            Write-Output ('Processing Deployment: "{0}" @[{1}] ' -f $_.DeploymentName, $_.timestamp)
            if (Remove-AzureRmResourceGroupDeployment -Name ($_.DeploymentName) -ResourceGroupName $($ResourceGroupName) -Verbose)
            {
                Write-Verbose ('Successfully removed deployment: "{0}" @[{1}] ' -f $_.DeploymentName, $_.timestamp)
            }
        }
    }
}

function Optimize-ResourceGroupDeployments
{
    param(
        [string]
        $ResourceGroupName = [string]::Empty,
        [int]
        [ValidateRange(10,800)] 
        $SkipLast = 75        
      )

    # check for single resource group deployment
    if ([string]::IsNullOrEmpty($ResourceGroupName))
    {
        $rgs = @(Get-AzureRmResourceGroup)
        if ($rgs.Count -eq 1)
        {
            $ResourceGroupName = ($rgs | Select-Object -First 1).ResourceGroupName
            Write-Verbose ("Using the single resource group {0}" -f $ResourceGroupName)
        }
        else
        {
            Write-Error 'Required Resource Group not defined'   
        }
    }

    $InitialCount = @(Get-AzureRmResourceGroupDeployment $($resourceGroupName)).Count
    Write-Output ('{0} deployments found in "{1}"' -f $InitialCount, $ResourceGroupName)            

    $DeploymentsToRemove = @(Get-Deployments -SkipLast $SkipLast -ResourceGroupName $ResourceGroupName)
    if ($DeploymentsToRemove.count -gt 0)
    {
        Write-Output ('Planning to remove {0} deployments from {1}, covering the range {2}-{3}' -f $DeploymentsToRemove.count, $ResourceGroupName,($DeploymentsToRemove | Select-Object -First 1).timestamp, ($DeploymentsToRemove | Select-Object -Last 1).timestamp)

        Remove-Deployments -ResourceGroupName $ResourceGroupName -Deployments $DeploymentsToRemove -Verbose

        $RevisedCount = @(Get-AzureRmResourceGroupDeployment $($resourceGroupName)).Count
        Write-Output ('Deployments in "{0}" reduced from {1} to {2}' -f $ResourceGroupName,$InitialCount,$RevisedCount)      
    }
    else
    {
        Write-Output ('No Deployments need be removed from "{0}"' -f $ResourceGroupName)      
    }
}