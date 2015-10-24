Function Connect-AzureRest
{
    Param ($username, $password)

    $body = "resource=https://management.core.windows.net/&client_id=1950a258-227b-4e31-a9cf-717495945fc2&grant_type=password&username=$username&scope=openid&password=$password"
    try
    {
        $result = invoke-restmethod -Uri "https://login.windows.net/Common/oauth2/token" -Method Post -Body $body -ErrorAction stop
    }
    Catch
    {
        
    }

    if ($result.access_token)
    {
        $authString = "Bearer $($result.access_token)"
        $authString
    }
    Else
    {
        Write-error "Error authenticating"
    }
    

}