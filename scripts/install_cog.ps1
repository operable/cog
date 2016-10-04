function ConvertTo-PlainString {
    param ($secureString)

    # Get the plain text version of the password
    $securePointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureString)
    $plainText = [Runtime.InteropServices.Marshal]::PtrToStringAuto($securePointer)
    
    # Free the pointer
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($securePointer)
    
    $plainText
}


function Get-InstallationInputs {
    # This function is responsible for getting all the required user inputs to the installation process
    return [PSCustomObject]@{
            BotSlackToken   = Read-Host 'Please enter the Slack bot API token';
            UserSlackHandle = Read-Host 'Please enter the slack handle of your slack user (not your bot)';
            Username        = Read-Host 'Please enter a username to create in Cog';
            Password        = ConvertTo-PlainString (Read-Host 'Please enter the password for the Cog user' -AsSecureString); 
            FirstName       = Read-Host 'Please enter the first name for the user'
            LastName        = Read-Host 'Please enter the last name for the user'
            Email           = Read-Host 'Please enter the email for the Cog user'
        }
}

function Create-CogConfiguration {
    param ($inputs, $cog_container)


    # Create a Cog user 
    & docker exec $cog_container cogctl users create "--first-name=$($inputs.FirstName)" "--last-name=$($inputs.LastName)" "--email=$($inputs.email)" "--username=$($inputs.Username)" "--password=$($inputs.Password)"

    # Associate the Cog user to a slack handle - this association is how permissions would be determined for that slack handle (only slack handles that
    # have user associated with them would have permissions to run anything). If you get a message similar to the following, then it means you're trying to invoke
    # a Cog command from a handle that has no associated Cog user (and hence no permissions):
    #
    #   I'm terribly sorry, but either I don't have a Cog account for you, or your Slack chat handle has not been registered. Currently, only registered users can interact with me.
    #   You'll need to ask a Cog administrator to fix this situation and to register your Slack handle.
    & docker exec $cog_container cogctl chat-handles create "--user=$($inputs.Username)" "--chat-provider=`"slack`"" "--handle=$($inputs.UserSlackHandle)"

    # Give the Cog user you created admin permissiosn
    & docker exec $cog_container cogctl groups add cog-admin "--user=$($inputs.Username)"
}

function Invoke-CogInstallation
{
    param ($inputs)

    if (-not $inputs) {
        Write-Error "No inputs provided to Invoke-CogInstallation"
        return
    }

    # Download the latest example docker-compose files (incl. an overrides file) from the operable/cog repository on github
    & curl https://raw.githubusercontent.com/operable/cog/master/docker-compose.yml -o docker-compose.yml
    & curl https://raw.githubusercontent.com/operable/cog/master/docker-compose.override.example.yml -o override.yml

    # Set the required environment variables
    $Env:SLACK_API_TOKEN = $inputs.BotSlackToken
    $Env:COG_HOST = "0.0.0.0"

    # Run docker-compose in a separate powershell console
    start powershell -ArgumentList "-command", "cd $pwd; docker-compose -f ./docker-compose.yml -f ./override.yml up"

    # TODO: Auto-detect ratehr than rely on user input
    Read-Host "We need to wait for the containers to start up. 
    Please press enter once the stream of outputs from docker-compose stops (should take ~2 min)"

    Write-Host "Searching for cog container..."
    $cog_container = & docker ps --format "{{.Names}}" | ? { $_ -match "_cog_\d+" }

    if (-not $cog_container) {
        Write-Error "Can't find Cog container - something went wrong with starting the docker-compose"
        return;
    }

    Write-Host "Found Cog container: $cog_container"
    Create-CogConfiguration $inputs $cog_container
}

function Install {
    $inputs = Get-InstallationInputs
    Invoke-CogInstallation $inputs
}

Install
