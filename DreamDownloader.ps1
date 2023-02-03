$pokemonSearchURI = "pokeapi.co/api/v2/pokemon/"
$allURI = "https://pokeapi.co/api/v2/pokemon?limit=100000&offset=0"

$searchClass = "fullMedia"
$mainURI = "https://archives.bulbagarden.net/w/api.php"
$subURI = "?action=opensearch&limit=500&search=File:"
$requestedSpecies = Read-Host -Prompt 'Species name (or "all")'
$requestedSpecies = $requestedSpecies.ToLower()

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function SearchForFilesBySpecies
{
	param(
		[string]$Species
	)
	
	$requestedIndex = -1
	
	try {
		$indexReq = Invoke-WebRequest -URI $pokemonSearchURI$Species
		$indexJson = $indexReq.Content | ConvertFrom-Json
		$requestedIndex = $indexJson.id
		while ($requestedIndex.Length -lt 3) {
			$requestedIndex = '0'+$requestedIndex
		}
	}
	catch [System.Net.WebException] {
		Write-Host 'Unrecognized species. Script will attempt to search regardless.'
		$requestedIndex = Read-Host -Prompt 'Species index'
	}

	$req = Invoke-Webrequest -URI $mainURI$subURI$requestedIndex$Species
	$results = $req.Content | ConvertFrom-Json

	$resultCount = 0

	foreach ($stringResult in $results[3]) {
		$resultCount = $resultCount+1
	}

	Write-Host 'Discovered' $resultCount 'files matching' $Species'. Saving...'

	foreach ($stringResult in $results[3]) {
		$pageReq = Invoke-Webrequest -URI $stringResult
		$classResult = $pageReq.ParsedHtml.getElementsByClassName($searchClass)[0]
		$finalName = $stringResult -replace ".*:"
		$fileReq = Invoke-Webrequest -URI $classResult.firstChild.firstChild.href -OutFile $finalName
	}
}

if ($requestedSpecies.Equals('all')) {
	$indexReq = Invoke-WebRequest -URI $allURI
	$result = $indexReq.Content | ConvertFrom-Json
	$results = $result.results
	foreach ($resource in $results) {
		try {
			$indexReq = Invoke-WebRequest -URI $resource.url
			$indexJson = $indexReq.Content | ConvertFrom-Json
			SearchForFilesBySpecies -Species $indexJson.name
		}
		catch [System.Net.WebException] { }
	}
} else {
	SearchForFilesBySpecies -Species $requestedSpecies
}

Write-Host 'Process completed.'