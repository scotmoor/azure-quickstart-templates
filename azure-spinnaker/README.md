# Create a new instance of Spinnaker running on a VM in Azure.  

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fscotmoor%2Fazure-quickstart-templates%2Fbasevm_param%2Fazure-spinnaker%2Fazuredeploy.json" target="_blank">
<img src="http://azuredeploy.net/deploybutton.png"/>
</a>
<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Fscotmoor%2Fazure-quickstart-templates%2Fbasevm_param%2Fazure-spinnaker%2Fazuredeploy.json" target="_blank">
<img src="http://armviz.io/visualizebutton.png"/>
</a>

This template deploys a new virtual machine with Spinnaker pre-installed into your subscription. Once deployed, the new virtual machine is ready to be configured for targeting deployments to the Azure platform.

The template will create two VMs in your subscription. The first is solely responsible for handling setup operations. Once the deployment has completed you may remove this VM and it's associated resoures.
The second VM wil be the actual instance of Spinnaker, identified by the VM name given during deployment. Once the second VM has beend deployed, you will need to remote into the machine, via ssh, to complete the configuration of Spinnaker (see steps below).  

## How to deploy this template

### Prequisite
Before deploying the the template, you must first copy the base image .vhd to a storage location within in your subscription.

1. Download the base image .vhd from <a href="https://azurespinnakertrial.blob.core.windows.net/vhds/azurespin-osDisk.0810160101.vhd?st=2016-09-01T23%3A27%3A00Z&se=2016-09-02T23%3A27%3A00Z&sp=rl&sv=2015-04-05&sr=b&sig=uS5Tv3B05fez2hJAQ%2BDXykizBSN3nLMR3UCzqH%2FMbpU%3D">here</a>
2. Upload the .vhd to a container in a storage account within the subscription where you will deploy the template
  - Be sure to note the path/URI of the uploaded .vhd. You will need to supply this value for the "Source Image URI" parameter
  
***NOTE***: The <a href="http://storageexplorer.com">Azure Storage Explorer</a> is a convenient tool for managing storage accounts in your subscription 

### Option 1: Deploy To Azure
1. Click the **Deploy To Azure** button at the top of this README.md. This will initiate a new template depoyment in the Azure Portal with the azuredeploy.json template loaded 
2. Set the template parameters appropriately and press OK
3. specify the resource group to deploy in to
4. review and accept the legal terms.
5. Press "create"

### Option 2: Deploy via powershell
1. Modify ***azuredeploy.parameters.json*** parameters file accordingly, be aware that this method can expose your local admin credential since it is defined in the parameters file.

2. Open Powershell command prompt, change folder to your template folder.

3. Authenticate to this session

  ```powershell
  Add-AzureRmAccount
  ```

4. Create the new Resource Group where your deployment will happen

  ```powershell
  New-AzureRmResourceGroup -Name "myResourceGroupName" -Location "centralus"
  ```

5. Deploy your template

  ```powershell
  New-AzureRmResourceGroupDeployment -Name "myDeploymentName" `
                                     -ResourceGroupName "myResourceGroupName" `
                                     -Mode Incremental `
                                     -TemplateFile .\azuredeploy.json `
                                     -TemplateParameterFile .\azuredeploy.parameters.json `
                                     -Force -Verbose 
  ```

## POST Deployment consfiguration steps:
After the deployment has completed, there are some additional configuration steps that must be performed directly on the virtual machine to configure Spinnaker for targeting deployments to Azure

1. First obtain the IP address of the Public IP resource associated with your VM. The name of Public IP resource associated with your VM can be located in the Azure portal by searching for the name of the VM specified in the template parameters followed by "PublicIP"
    
    Example: If VM Name = "myspinnakerVM" then Public IP resource = "myspinnakerVMPublicIP"
2. ssh into the VM where Spinnaker in installed by executing the following command:

    ```
    ssh <admin_username>@<ip address>
    ```
    You will be prompted for the password of the admin user account specified in the deployment template parameters



********************
  ***NOTE***: For the version of the template in this branch, you must first execute the following curl command before continuing:
  ``` 
  sudo curl -o /opt/spinnaker/config/azure_config/initAzureSpinnaker.sh https://raw.githubusercontent.com/scotmoor/azure-quickstart-templates/basevm_param/azure-spinnaker/scripts/initAzureSpinnaker.sh
  ```
********************



3. Once logged on, execute the following command:

    ```
    sudo bash /opt/spinnaker/config/azure_config/initAzureSpinnaker.sh
    ```
    
    This script will require you to securely log into you Azure account. When you see the following output in the command window, follow the instructions to complete the login process
    ```
    ******* PLEASE LOGIN *******
    Authenticating...info:    To sign in, use a web browser to open the page https://aka.ms/devicelogin. Enter the code ######### to authenticate.
    ```
    If you have more than one subscription, you will be asked to specify which subscription to use after logging in by simply typing in the name of the subscription as it appears in the list.

    After completing the login process, the script will create the necessary application and Active Directory service principal in your subscription to enable Spinnaker to communicte to your Azure subscription. It will also launch the various Spinnaker services 

    NOTE: At various points, the script will pause and you will be prompted to manually continue the script by pressing 'Enter'. Or, you may press Ctl-C to abort the script.


## Configuring Port forwarding
To configure an ssh tunnel, follow the instructions outlined in step 2 of the <a href="http://www.spinnaker.io/docs/creating-a-spinnaker-instance">Creating a Spinnaker Instance</a> document.                     