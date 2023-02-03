$replacements = @(
	@{Name1="nidoran-f";Name2="nidoran"},
	@{Name1="nidoran-m";Name2="nidoran"},
	@{Name1="farfetchd";Name2="farfetch'd"},
	@{Name1="mr-mime";Name2="mr. mime"},
	@{Name1="deoxys-normal";Name2="deoxys"},
	@{Name1="wormadam-plant";Name2="wormadam"},
	@{Name1="giratina-altered";Name2="giratina"},
	@{Name1="shaymin-land";Name2="shaymin"},
	@{Name1="basculin-red-striped";Name2="basculin"},
	@{Name1="darmanitan-standard";Name2="darmanitan"},
	@{Name1="tornadus-incarnate";Name2="tornadus"},
	@{Name1="thundurus-incarnate";Name2="thundurus"},
	@{Name1="landorus-incarnate";Name2="landorus"},
	@{Name1="keldeo-ordinary";Name2="keldeo"},
	@{Name1="meloetta-aria";Name2="meloetta"},
	@{Name1="meowstic-male";Name2="meowstic"},
	@{Name1="aegislash-shield";Name2="aegislash"},
	@{Name1="pumpkaboo-average";Name2="pumpkaboo"},
	@{Name1="gourgeist-average";Name2="gourgeist"},
	@{Name1="zygarde-50";Name2="zygarde"},
	@{Name1="oricorio-baile";Name2="oricorio"},
	@{Name1="lycanroc-midday";Name2="lycanroc"},
	@{Name1="wishiwashi-solo";Name2="wishiwashi"},
	@{Name1="minior-red-meteor";Name2="minior"},
	@{Name1="toxtricity-amped";Name2="toxtricity"},
	@{Name1="mr-rime";Name2="mr. rime"},
	@{Name1="eiscue-ice";Name2="eiscue"},
	@{Name1="indeedee-male";Name2="indeedee"},
	@{Name1="morpeko-full-belly";Name2="morpeko"},
	@{Name1="urshifu-single-strike";Name2="urshifu"},
	@{Name1="basculegion-male";Name2="basculegion"},
	@{Name1="enamorus-incarnate";Name2="enamorus"}
)

$pokemonCount = 1007
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
	
	$requestedIndex = "-1"
	
	try {
		$indexReq = Invoke-WebRequest -URI $pokemonSearchURI$Species
		$indexJson = $indexReq.Content | ConvertFrom-Json
		$requestedIndex = $indexJson.id.ToString()
		while ($requestedIndex.Length -lt 3) {
			$requestedIndex = '0'+$requestedIndex
		}
	}
	catch [System.Net.WebException] {
		Write-Host 'Unrecognized species. Script will attempt to search regardless.'
		$requestedIndex = Read-Host -Prompt 'Species index'
	}

	$replaced = $false
	foreach ($replacement in $replacements) {
		if ($Species.Equals($replacement.Name1)) {
			$Species = $replacement.Name2
			$replaced = $true
		}
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
	$restart = Read-Host -Prompt 'Start from a specific species in the list? (y/n)'
	$specResume = ' '
	$beginScanning = $true
	if ($restart -eq 'y') {
		$beginScanning = $false
		$specResume = Read-Host -Prompt 'Species to begin from'
		$specResume = $specResume.ToLower()
	}
	$doReplaces = Read-Host -Prompt "Scan for regex replacement names? If you don't know what this means, you don't need it. (y/n)"
	if ($doReplaces -eq 'y') {
		foreach ($replacement in $replacements) {
			SearchForFilesBySpecies -Species $replacement.Name1
		}
	}
	$indexReq = Invoke-WebRequest -URI $allURI
	$result = $indexReq.Content | ConvertFrom-Json
	$results = $result.results
	$countedPokemon = 0
	foreach ($resource in $results) {
		try {
			$indexReq = Invoke-WebRequest -URI $resource.url
			$indexJson = $indexReq.Content | ConvertFrom-Json
			if ($indexJson.name -eq $specResume) {
				$beginScanning = $true
			}
			if ($beginScanning) {
				SearchForFilesBySpecies -Species $indexJson.name
			}
			$countedPokemon = $countedPokemon+1
			if ($countedPokemon -gt $pokemonCount) {
				return
			}
		}
		catch [System.Net.WebException] { }
	}
} else {
	SearchForFilesBySpecies -Species $requestedSpecies
}

Write-Host 'Process completed.'