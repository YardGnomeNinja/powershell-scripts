<#
.SYNOPSIS
	Generate SDK based on Swagger documentation

.DESCRIPTION
	Requires Docker image https://hub.docker.com/r/jimschubert/swagger-codegen-cli/

.EXAMPLE
	P7
	--
		.\swagger-codegen.ps1 `
		-loginPage http://www.thezonelive.com/p7/content/pgLogin.aspx `
		-usernameFieldId txtUsername `
		-passwordFieldId txtPassword `
		-username <yourusername> `
		-password <yourpassword> `
		-swaggerPage https://www.thezonelive.com/p7/swagger/docs/v1 `
		-configPath c:\p7sdk\ `
		-configFilename sdkconfig.json `
		-outputPath c:\p7sdk\

	The Zone
	--------
		.\swagger-codegen.ps1 `
		-loginPage https://www.thezonelive.com/zone `
		-formIndex 1 `
		-usernameFieldId Username `
		-passwordFieldId Password `
		-username <yourusername> `
		-password <yourpassword> `
		-swaggerPage https://www.thezonelive.com/zone/swagger/docs/v1 `
		-configPath c:\zonesdk\ `
		-configFilename sdkconfig.json `
		-outputPath c:\zonesdk
#>

param (
    [string]$loginPage,
    [Parameter(Mandatory=$true)][string]$swaggerPage,
    [Parameter(HelpMessage="Used when the login form is not the first in the page structure. Default: 0")][int]$formIndex = 0,
    [string]$usernameFieldId,
    [string]$passwordFieldId,
    [string]$username,
    [string]$password,
    [string]$configPath = $PSScriptRoot,
    [string]$configFilename = "sdkconfig.json",
    [string]$outputPath = $PSScriptRoot
 )
 
if ($loginPage -eq "") {
	# Request Swagger page without auth
	Write-Host "Navigating to $swaggerPage..."
	$swaggerRequest = Invoke-WebRequest -Uri $swaggerPage
}
else {
	# Visit site, get login form info, insert username and password
	Write-Host "Navigating to $loginPage to get login form..."
	$pgLoginResponse = Invoke-WebRequest $loginPage -SessionVariable thisSession
	$loginForm = $pgLoginResponse.Forms[($formIndex)]
	#$loginForm | Format-List #Format form fields into list
	#$loginForm.Fields #Display list of form fields

	$loginForm.Fields[$usernameFieldId]=$username
	$loginForm.Fields[$passwordFieldId]=$password

	# Submit login form and get session data
	Write-Host "Logging in and retrieving session..."
	$loginRequest = Invoke-WebRequest -Uri ($loginPage + $loginForm.Action) -WebSession $thisSession -Method POST -Body $loginForm.Fields

	# Request Swagger page using session data
	Write-Host "Navigating to $swaggerPage..."
	$swaggerRequest = Invoke-WebRequest -Uri $swaggerPage -WebSession $thisSession
}

# Save Swagger request as swagger.json
$swaggerRequest.Content | Out-File ($outputPath + "\swagger.json") -encoding ASCII | out-null

# Call command in Docker container to generate SDK
Write-Host "Running Docker application container command to generate SDK at $outputPath..."
$dockerCommand =	"docker run -it" + 
					" -v " + $outputPath + ":/swagger-api/out" +
					" -v " + $configPath + ":/swagger-api/config" +
					" jimschubert/swagger-codegen-cli generate" +
					" -i /swagger-api/out/swagger.json" +
					" -l csharp" +
					" -c /swagger-api/config/" + $configFilename + 
					" -o /swagger-api/out/"

Invoke-Expression $dockerCommand | out-null

# Clean up
Write-Host "Cleaning up..."
Invoke-Expression ("rm " + $outputPath + "\swagger.json")