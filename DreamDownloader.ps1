$pokemonSearchURI = "pokeapi.co/api/v2/pokemon/"

$searchClass = "fullMedia"
$mainURI = "https://archives.bulbagarden.net/w/api.php"
$subURI = "?action=opensearch&limit=500&search=File:"
$requestedSpecies = Read-Host -Prompt 'Species name'
$requestedSpecies = $requestedSpecies.ToLower()
$requestedIndex = -1

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

try {
	$indexReq = Invoke-WebRequest -URI $pokemonSearchURI$requestedSpecies
	$indexJson = $indexReq.Content | ConvertFrom-Json
	$requestedIndex = $indexJson.id
}
catch [System.Net.WebException] {
	Write-Host 'Unrecognized species. Script will attempt to search regardless.'
	$requestedIndex = Read-Host -Prompt 'Species index'
}

$req = Invoke-Webrequest -URI $mainURI$subURI$requestedIndex$requestedSpecies
$results = $req.Content | ConvertFrom-Json

$resultCount = 0

foreach ($stringResult in $results[3]) {
		$resultCount = $resultCount+1
}

Write-Host 'Discovered' $resultCount 'matching files. Saving...'

foreach ($stringResult in $results[3]) {
	if ($stringResult.Contains("archives.bulbagarden.net")) {
		$pageReq = Invoke-Webrequest -URI $stringResult
		$classResult = $pageReq.ParsedHtml.getElementsByClassName($searchClass)[0]
		$finalName = $stringResult -replace ".*:"
		$fileReq = Invoke-Webrequest -URI $classResult.firstChild.firstChild.href -OutFile $finalName
	}
}

Write-Host 'Process completed.'