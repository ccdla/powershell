
# Change subscription
Set-AzContext -SubscriptionId a1a2366-3d81-4fc9-931a-bca12cfe60da # Set the subscription you want to work in

# Tags
    # Get resource existing tags
    (Get-AzResource -Name 'VM01').Tags 
    # or:
    $vm = Get-AzResource -ResourceName 'VM01' -ResourceGroupName 'e19110701_RG'

    # update tags
    # set a reference to a resources tag first
    $tags = (Get-AzResource -ResourceName 'VM01').Tags # define an object with the existing tags. this is necessary so it doesnt overwrite tags
    $tags += @{Key = 'Value'; Dept = 'Finance'} # adds the following tag to the existing tag list
    # Then apply the tags
    Set-AzResource -ResourceId (Get-AzResource -Name 'VM01').Id -Tag $tags -Force
    # Validate the tags applied in the output:
    # Tags              : {Key, Dept}
    Get-AzTag  # get all the tags for the subscription
    (Get-AzResource -Tag @{Key = 'Value'}).Name #give the names of all the resources that have the following tag(s)

    # Remove all tags - set it to an empty tag dictionary
    Set-AzResource -ResourceId (Get-AzResource -Name 'VM01').Id -Tag @{} -Force

# Azure Policy
    $policy_def = Get-AzPolicyDefinition | ?{$_.Properties.DisplayName -eq "Audit VMs that do not use managed disks"} # get the policy definition that you want to assign
    New-AzPolicyAssignment -Name "Audit VMs" -DisplayName "Audit VMs" -Scope (Get-AzResourceGroup -Name e19110701_RG).ResourceId -PolicyDefinition $policy_def # Assign the definition to the resource (this one is applied to the resource group)

# Access Control (IAM)

    Get-AzRoleAssignment -ResourceGroupName 'e19110701' # Get all the assigned roles for this  resource group
    # assign a role to a user
    New-AzRoleAssignement -SignInName 'e19110701@toncoso.com' -RoleDefinitionName 'Azure Sentinel Contributer' -ResourceGroupName 'e19110701_RG' 
    # assign a role to a group
    $groupid = (Get-AzureAD Group -Name 'TestGroup').ObjectId # Find the Groups ObjectID
    New-AzRoleAssignment -ObjectId $groupid -RoleDefinitionName 'Azure Sentinel Contributer' -ResourceGroupName 'e19110701_RG' 

    # RBAC Role - Custom Role Creation
    $subid = "wer2342-23234-234234-34faw3"

    $customrole = Get-AzRoleDefinition "Virtual Machine Contributer" # get a similar built-in role as a baseline
    $customrole.Id = $null # theres no value assigned yet
    $customrole.Name = "Virtual Machine Starter" # give it a custom name
    $customrole.Actions.Clear() # clear all the permissions from the built-in role
    $customrole.Actions.Add("Microsoft.Storage/*/read") # adding resource permissions
    $customrole.Actions.Add("Microsoft.Network/*/read") # adding resource permissions
    $customrole.Actions.Add("Microsoft.Compute/virtualMachines/start/action") # adding resource permissions
    $customrole.Actions.Add("Microsoft.Authorization/*/read") # adding resource permissions
    $customrole.Actions.Add("Microsoft.Insights/alertRules/*") # adding resource permissions
    $customrole.AssignableScopes.Clear() # remove existing assignable scope settings
    $customrole.AssignableScopes.Add('/subscriptions/$subid') # assignable scope to a subscription/resourcegroup/resource

    New-AzRoleDefinition -Role -customrole # invoke it

# Resource Providers
    Get-AzProviderOperations -OperationSearchString "Microsoft.Computer/*/action" #shows all the possible "action" for the Microsoft.Computer resource provider

    #register a resource provider
    Get-AzResourceProvider -ListAvaliable # lists all the avaliable providers
    Get-AzResourceProvider -ListAvaliable | ?{_.ProviderNamespace -eq "Micosoft.BotService"} # Get the current status

    #register
    Register-AzResourceProvider -ProviderNamespace 'Microsoft.BotService'

    #validate registration
    Get-AzResourceProvider -ListAvaliable | ?{_.ProviderNamespace -eq "Micosoft.BotService"} # Get the current status

# Resource Groups

    New-AzResourceGroup -Name e19110701_RG -Location 'East US 2'
    Remove-AzResourceGroup -Name e19110701_RG 
    # Resource Locks
    New-AzResourceLock -LockName 'TestLockNoDelete' -LockLevel CanNotDelete -ResourceGroupName 'e19110701_RG' # add a lock
    New-AzResourceLock -LockName 'TestLockNoDelete' -LockLevel ReadOnly -ResourceGroupName 'e19110701_RG' # add a lock

    #Remove a lock
    $lockid = (Get-AzResourceLock -ResourceGroupName 'e191101701_RG').LockId
    Remove-AzResourceLock -LockId $lockid

# Azure AD
    # Install Azure AD Module
    Install-Module -Name AzureAD

    # Load the AAD Module
    Import-Module -Name AzureAD
    $adcreds = Get-Credentials

    Connect-AzureAD -Credential $adcreds
    Get-AzureADCurrentSessionInfo 
    Get-AzureADTenantDetail # get tenant ID / object ID
    Get-AzureADDomain # get the domains in the tenant

    #Find a user
    Get-AzureADUser -SearchString "TestUser"
    # Filter
    Get-AzureADUser -Filter "State eq 'PA'"

    #Create a new user
    $domain = 'toncoso.onmicrosoft.com'
    $PasswordProfile = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordProfile
    $PasswordProfile.Password = 'Password123'

    $user = @{

    }

    $newUser = New-AzureADUser $user

# Networking
    # Create a NSG
    $nsg = New-AzNetworkSecurityGroup `
        -ResourceGroupName e19110701_RG `
        -Location eastus2 `
        -Name myNSG `
        -SecurityRules $webRule, $rule #apply the rules that were created below

    # Create a ASG
    $webasg = New-AzApplicationSecurityGroup `
        -ResourceGroupName e19110701_RG `
        -Name myAsgWebServers `
        -Location eastus2

    # Create new rules
    $rule = New-AzNetworkSecurityRuleConfig `
        -Name "Allow-All-Rule" `
        -Access Allow `
        -Protocol Tcp `
        -Direction Inbound `
        -Priority 100 `
        -SourceAddressPrefix Internet `
        -SourcePortRange * `
        -DestinationApplicationSecurityGroup $webasg.Id
        -DestinationPortRange 80,443

    # Create a vNet
    $vnet = New-AzVirtualNetwork `
        -ResourceGroupName e19110701_RG `
        -Location eastus2 `
        -Name mynewVNET `
        -AddressPrefix 10.0.0.0/16

    # Create a subnet
    $subnet = AzVirtualSubnetConfig `
        -Name mySubnet `
        -VirtualNetwork $vnet `
        -AddressPrefix "10.0.1.0/24" `
        -NetworkSecurityGroup $nsg

    # Associate the subnet to the vnet
    $vnet | Set-AzVirtualNetwork
    # Create a Public IP Address
    $pubicipadd = New-AzPublickIpAddress `
        -AllocationMethod Dynamic `
        -ResourceGroupName e19110701_RG `
        -Location eastus2 `
        -Name myPublicIpAdd

    # Create NIC cards
    $nic = New-AzNetworkInterface `
        -Location eastus2 `
        -Name myNIC `
        -ResourceGroupName e19110701_RG `
        -subnetId $vnet.Subnets[0].Id `
        -ApplicationSecurityGroupId $webasg.Id ` # assign the nic to this ASG
        -PublicIpAddressId $publicipadd.Id #assign it to the public Ip Address

# DNS
# Managed Identity
# from the VM that has MI enabled
Connect-AzAccount -MSI -Subscription jaskfj-3242-2r3r-a3 # allows the resource to connect using their MSI

# access a azure resource using the system managed identity from the resources itself
$context = New-AzStorageContext -StorageAccountName teststorageblob -UseConnectedAccount #use the MSI

# Azure Key Vault
    $secret = Get-AzKeyVaultSecret -VaultName testvault -Name Secret #assign the variable to the vault secret
    $secret.SecretValueText #the actual plaintext password

# Automation Account
    New-AzAutomationAccount 

    # using asets
    $var = Get-AzAutomationVariable -ResourceGroupName e19110701_RG -AutomationAccountName AutomationAccount -Name "NameYouAssignedtheAsset"
    $var = Get-AzAutomationCredential -ResourceGroupName e19110701_RG -AutomationAccountName AutomationAccount -Name "NameYouAssignedtheAsset"

    #Publish
    Publish-AzAutomationRunbook -Name RunbookName -ResourceGroupName RG -AutomationAccountName -AccountName

    #Manually run it to test
    Start-AzAutomationRunbook -Name RunbookName -Parameters @{VMName ='demovm'; RGName = 'RG'} ResourceGroupName e19110701_RG -AutomationAccountName AutomationAccount

    #Assign a schedule
    New-AzAutomationSchedule 

    #Associate schedule with runbook
    Register-AzAutomationScheduledRunbook -RunbookName RunbookName -ScheduleName 'name' -Parameters @{VMName ='demovm'; RGName = 'RG'} ResourceGroupName e19110701_RG -AutomationAccountName AutomationAccount

    #Get output logging
    Get-AzAutomationJobOutput -id "job id code" -ResourceGroupName ResourceGroupName e19110701_RG -AutomationAccountName AutomationAccount -Stream any
    Set-AzAutomationRunbook -Name RunbookName ResourceGroupName e19110701_RG -AutomationAccountName AutomationAccount -LogVerbose $true