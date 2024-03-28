$resource_group_name = "MyResourceGroup"
$resource_group_Location = "centralus"

# Check if the resource group exists, if not create it
$existingResourceGroup = Get-AzResourceGroup -Name $resource_group_name -ErrorAction SilentlyContinue
if (-not $existingResourceGroup) {
    Write-Host "Creating resource group $resource_group_name..."
    New-AzResourceGroup -Name $resource_group_name -Location $resource_group_Location
    # Wait for the resource group creation
    Write-Host "Waiting for the resource group to be created..."
    do {
        $existingResourceGroup = Get-AzResourceGroup -Name $resource_group_name -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 10
    } while (-not $existingResourceGroup)
}
else {
    Write-Host "Resource group $resource_group_name already exists. Proceeding..."
}

# Create a detailed network security group
$rule1 = New-AzNetworkSecurityRuleConfig -Name rdp-rule -Description "Allow RDP" `
    -Access Allow -Protocol Tcp -Direction Inbound -Priority 300 -SourceAddressPrefix `
    Internet -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389

$rule2 = New-AzNetworkSecurityRuleConfig -Name web-rule -Description "Allow Http" `
    -Access Allow -Protocol Tcp -Direction Inbound -Priority 400 -SourceAddressPrefix `
    Internet -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 80 

$NSG = New-AzNetworkSecurityGroup -ResourceGroupName $resource_group_name -Location $resource_group_Location -Name "MYNSG" -SecurityRules $rule1,$rule2

Write-Host "Waiting for NSG to be created..."
do {
    $NSG = Get-AzNetworkSecurityGroup -Name 'MYNSG' -ResourceGroupName $resource_group_name -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 10
} while (-not $NSG)

# Check if NSG was successfully created
if (-not $NSG) {
    Write-Error "Failed to create NSG. Exiting..."
    exit
}

# Create a storage account
$storage_acc_name = "jobansstorageacc"
$storage_acc_location = "centralus"
$storageacc = New-AzStorageAccount -ResourceGroupName $resource_group_name -Name $storage_acc_name -Location $storage_acc_location -SkuName "Standard_LRS" -Kind "StorageV2"

Write-Host "Waiting for storage account to be created..."
do {
    $storageacc = Get-AzStorageAccount -ResourceGroupName $resource_group_name -Name $storage_acc_name -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 10
} while (-not $storageacc)

# Check if storage account was successfully created
if (-not $storageacc) {
    Write-Error "Failed to create storage account. Exiting..."
    exit
}

# Create a Public IP address
$publicIp = New-AzPublicIpAddress -ResourceGroupName $resource_group_name -Name "MyPublicIP" -AllocationMethod Static -Location $resource_group_Location

# Wait for Public IP creation
Write-Host "Waiting for Public IP to be created..."
do {
    $publicIp = Get-AzPublicIpAddress -ResourceGroupName $resource_group_name -Name "MyPublicIP" -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 10
} while (-not $publicIp)

# Check if Public IP was successfully created
if (-not $publicIp) {
    Write-Error "Failed to create Public IP. Exiting..."
    exit
}

# Create a subnet configuration
$subnetConfig = New-AzVirtualNetworkSubnetConfig -Name "MySubnet" -AddressPrefix "10.0.0.0/24"

# Create a virtual network
$vnet = New-AzVirtualNetwork -ResourceGroupName $resource_group_name -Location $resource_group_Location -Name "MyVNet" -AddressPrefix "10.0.0.0/16" -Subnet $subnetConfig

# Wait for Virtual Network creation
Write-Host "Waiting for Virtual Network to be created..."
do {
    $vnet = Get-AzVirtualNetwork -ResourceGroupName $resource_group_name -Name "MyVNet" -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 10
} while (-not $vnet)

# Check if Virtual Network was successfully created
if (-not $vnet) {
    Write-Error "Failed to create Virtual Network. Exiting..."
    exit
}

# Create a network interface and associate it with NSG, public IP, and subnet
$nic = New-AzNetworkInterface -Name "MyNIC" -ResourceGroupName $resource_group_name -Location $resource_group_Location -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $publicIp.Id -NetworkSecurityGroupId $NSG.Id

# Wait for NIC creation
Write-Host "Waiting for NIC to be created..."
do {
    $nic = Get-AzNetworkInterface -Name "MyNIC" -ResourceGroupName $resource_group_name -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 10
} while (-not $nic)

# Check if NIC was successfully created
if (-not $nic) {
    Write-Error "Failed to create NIC. Exiting..."
    exit
}

# Create the VM configuration
$VM_name = "jobans-vm"
$cred = Get-Credential -Message "Enter a username and password for the virtual machine."
$VM = New-AzVMConfig -VMName $VM_name -VMSize 'Standard_DS1_v2'
$VM = Set-AzVMOperatingSystem -VM $VM -Windows -ComputerName $VM_name -Credential $cred -ProvisionVMAgent -EnableAutoUpdate
$VM = Add-AzVMNetworkInterface -VM $VM -Id $nic.Id

# Create the OS disk
$VM = Set-AzVMOSDisk -VM $VM -Name "osdisk1" -CreateOption FromImage -Windows

# Create the VM
$GETVM=New-AzVM -ResourceGroupName $resource_group_name -Location $resource_group_Location -VM $VM -ErrorAction SilentlyContinue
# Wait for NIC creation
Write-Host "Waiting for VM to be created..."
do {
    $GETVM = Get-AzVM -Name $VM_name -ResourceGroupName $resource_group_name -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 10
} while (-not $GETVM)

# Check if NIC was successfully created
if (-not $GETVM) {
    Write-Error "Failed to create VM. Exiting..."
    exit
}
Write-Host "All resources created Successfully"
