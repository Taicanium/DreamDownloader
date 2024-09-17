<# There are certain names on the PokeAPI website that include
identifiers (-normal, -male, etc) that Bulbagarden doesn't use.
We can modify these names so that Bulbagarden CAN recognize
them, but three names require specific changes beyond just
cutting everything off past a '-'. #>

$replacements = @(
	@{Name1="farfetchd";Name2="farfetch'd"},
	@{Name1="mr-mime";Name2="mr. mime"},
	@{Name1="mr-rime";Name2="mr. rime"}
)

$pokemonCount = 1024

$pokemonSearchURI = "pokeapi.co/api/v2/pokemon/" <# We start with this base web address, and we will later stick Pokemon names on the end of it to get the Pokedex entry numbers. #>

$allURI = "https://pokeapi.co/api/v2/pokemon?limit=100000&offset=0" <# We'll call this web address if and only if the user wants to download all Pokemon at once. This will get us all the names, rather than going one-by-one via index. #>

$mainURI = "https://archives.bulbagarden.net/w/index.php" <# We'll call the Bulbagarden frontend API to initiate a raw search... #>

$subURI = "?title=Special:Search&limit=500&offset=0&profile=images&search=" <# ...and we'll use these parameters while narrowing things down by Pokemon name and index. #>

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 <# PowerShell requires that we set a specific security protocol (TLS12) before conducting user-level web requests. There's no need to know the underlying technology. #>

function SearchForFilesBySpecies
{
	param(

		[string]$Species <# This function takes one parameter: The name of the species the user (or script) wants to download. #>
	)
	
	$foundFiles = New-Object System.Collections.Generic.List[System.Object] <# If we're downloading concept art, we'll need to keep track of which files we've already downloaded. Why will become apparent later. #>

	$requestedIndex = "-1" <# Start by initializing the index to -1. If it STAYS -1, we'll know that something went wrong. #>
	
	$global:ProgressPreference = 'SilentlyContinue' <# Disable progress reporting for web downloads; Powershell's console progress bars are inefficient and would vastly slow down this script. #>

	try {

		$indexReq = Invoke-WebRequest -URI $pokemonSearchURI$Species <# Actually perform the web request to PokeAPI. #>

		$indexJson = $indexReq.Content | ConvertFrom-Json <# Assuming it succeeds, the result will be in JSON format; here, we convert it to a PowerShell table for easier lookup. #>

		$requestedIndex = $indexJson.id.ToString() <# Grab the Pokedex entry number, and convert it to a string. #>

		while ($requestedIndex.Length -lt 3) { <# If the index is less than 100... #>

			$requestedIndex = '0'+$requestedIndex <# ...pad it with leading 0s to comply with Bulbagarden's filename format. #>
		}
	}

	catch [System.Net.WebException] { <# If PokeAPI returns an error, that means it didn't recognize the species name. #>

		Write-Host 'Unrecognized species. Script will attempt to search regardless.' <# However, let's account for that just in case the user is searching for a newly created 'mon that PokeAPI hasn't added yet. #>

		$requestedIndex = Read-Host -Prompt 'Species index' <# Ask the user to specify the index manually. #>
	}

	foreach ($replacement in $replacements) {
		if ($Species.Equals($replacement.Name1)) { <# If the species name falls into the replacement List at the start of the file... #>

			Write-Host 'Exchanging' $Species 'for' $replacement.Name2'.' <# ...advise the user of the change... #>
			$Species = $replacement.Name2 <# ...and actually do the replacement. Exchange "mr-mime" for "mr. mime", etc. #>
			$replaced = $true
		}
	}

	if ([int]$requestedIndex -lt 984) { <# The Paradox Pokemon start at 984. Their names all include dashes. #>
		$Species = $Species -replace "-.*",""
	}

	$req = Invoke-Webrequest -URI $mainURI$subURI$requestedIndex$Species <# Now that we have our species name and our Pokedex number, make the search request to Bulbagarden. #>

	$images = $req.Images.src <# Give ourselves a short name for the web addresses to each file result. PowerShell makes this easy: In a lower-level language like C++, we'd have to iterate through each item in the List and take out the 'src' elements one at a time. #>
	
	New-Item -ItemType Directory -Force -Path .\$Species | Out-Null <# Since a single species search can easily return hundreds of files, we'll create subdirectories for each species. If the subdirectory already exists, the -Force option suppresses a resulting error message. Piping the command into Out-Null suppresses output with info about the newly created directory; the Batch equivalent would be @echo off. #>

	Write-Host 'Discovered' ($images.Count - 1) 'files matching' $Species'. Trimming and saving...' <# Let the user know how many search results we found. We subtract 1 from this count because it includes a MediaWiki logo present on the search results page. #>

	foreach ($stringResult in $images) { <# Go through our search results. #>

		if (-not($stringResult.Contains("mediawiki")) -and -not($stringResult.Contains("jpg/"))) { <# We want to first make sure this isn't the MediaWiki logo previously mentioned. We also limit ourselves to PNG files, because JPG files on the archives are generally photos of merchandise; we only want artwork. #>
				
			$foundFiles.Add($stringResult) <# Record the file name. #>

			$finalUri = $stringResult -replace "/thumb","" -replace "png/.*","png" <# The results link us to thumbnail images scaled down to 120px. We can get the full-sized image URL by manipulating it. First we remove the thumbnail indicator, and then we remove the suffix that normally dictates the size of the thumbnail. #>

			$finalName = $finalUri -replace ".*/" <# Grab the file's actual name by removing the rest of the web address. #>

			try {
				
				$fileReq = Invoke-Webrequest $finalUri -OutFile .\$Species\$finalName <# Finally, now that we have the file name and address, call a web request directly to the file, and save it locally. #>
			}
			catch {
				<# Sometimes an empty filename can appear in our results, which would otherwise cause an error if we didn't catch it here. #>
			}
			
			<# This is also why we used the frontend API (/w/index.php) rather than the developer API (/w/api.php):
			The developer search function links us to the file namespace pages on Bulbagarden Archives, but not the
			files directly. That means we'd have to make three web requests per file - one to the API, one to the
			file page, and one to the raw file. By manipulating URLs on the frontend search page, we can save
			ourselves the second of those three requests. Since a full search easily runs into the tens of thousands
			of files, that translates to a huge amount of web traffic and thereby time saved. #>
		}
	}
	
	$conceptReq = Invoke-Webrequest -URI $mainURI$subURI$Species <# As an additional feature, we will now search for concept art files in the related category on Bulbagarden. These are formatted without the Pokedex number. #>
	
	$conceptImgs = $conceptReq.Images.src
	
	Write-Host 'Discovered' ($conceptImgs.Count - 1) 'supplementary files matching' $Species'. Trimming and saving...' <# This number is sure to be several times the previous one, but only a handful are actually worth saving; most are anime or merchandise screenshots, which we don't (currently) want. #>
	
	foreach ($stringResult in $conceptImgs) {
		
		$strResLower = $stringResult.ToLower() <# Make it lowercase to ease the scanning function in the next line. #>
		
		if (-not($strResLower.Contains("mediawiki")) -and -not($foundFiles -contains $stringResult) -and ($strResLower.Contains("concept") -or $strResLower.Contains("sugimori") -or $strResLower.Contains("beta") -or $strResLower.Contains("shell"))) { <# As far as I can determine, all concept files contain at least one of these four words - official concept art; Ken Sugimori's concept art posted to Tumblr; beta design concept art; and detailed concepts of the shells of Alolan legendaries, respectively. #>
			
			$finalUri = $stringResult -replace "/thumb","" -replace "png/.*","png" -replace "jpg/.*","jpg" <# Some of these files are in JPG format, so we have to allow for them here. #>
			$finalName = $finalUri -replace ".*/"
			
			try {
				$fileReq = Invoke-Webrequest $finalUri -OutFile .\$Species\$finalName
			}
			catch {	}
		}
	}
	
	$global:ProgressPreference = 'Continue' <# Reset the progress preference from earlier to its default value. #>
}

$requestedSpecies = Read-Host -Prompt 'Species name (or "all")' <# Ask the user if they want to download all species images indiscriminately. #>

$requestedSpecies = $requestedSpecies.ToLower() <# PokeAPI requires that we search by names all in lowercase. #>

if ($requestedSpecies.Equals('all')) {

	$restart = Read-Host -Prompt 'Start from a specific species in the list? (y/n)' <# In case the script was previously ended prematurely, ask the user if they'd like to start from where they left off. #>

	$specResume = ' ' <# Start by assuming the user doesn't want to do that. #>
	$beginScanning = $true

	if ($restart -eq 'y') { <# If they do... #>
		$beginScanning = $false

		$specResume = Read-Host -Prompt 'Species to begin from' <# ...ask them where exactly their starting point will be. #>
	}

	$indexReq = Invoke-WebRequest -URI $allURI <# Whether or not the regex names were downloaded, we now begin our search proper. Begin by downloading all Pokemon names from PokeAPI. The specific function we're calling will give us not just the names, but further search URLs that we can plug right back into PokeAPI to get the indexes. #>

	$result = $indexReq.Content | ConvertFrom-Json <# Convert the names to a table. #>

	$results = $result.results <# Give the result a non-redundant name. #>
	$countedPokemon = 0
	
	$global:ProgressPreference = 'SilentlyContinue'

	foreach ($resource in $results) { <# For every result in the List... #>
		try {

			$indexReq = Invoke-WebRequest -URI $resource.url <# ...call the associated search URL... #>

			$indexJson = $indexReq.Content | ConvertFrom-Json <# ...and as always, convert it to a table. #>

			if ($indexJson.name -eq $specResume.ToLower()) { <# Check if the user specified a starting point earlier. #>

				$beginScanning = $true <# If they did, and this species matches that starting point, then let the script know to start downloading. #>
				
				Write-Host "`n"
			}

			if ($beginScanning) { <# If and only if we've been given that prior go-ahead or we're downloading everything... #>

				SearchForFilesBySpecies -Species $indexJson.name <# ...call our custom download function. #>
			} else {
				
				Write-Host -NoNewLine "`r"$countedPokemon" Pokemon skipped" <# Otherwise, let the user know where we are in the list. #>
			}

			$countedPokemon = $countedPokemon+1 <# Increase the counter of species we've downloaded. #>

			if ($countedPokemon -gt $pokemonCount) { <# If the counter has reached the end of the Paradox Pokemon... #>

				return <# ...halt the search, because the only remaining matches are alternate forms. #>
			}
		}

		catch [System.Net.WebException] { } <# If an error occurs, do not exit the script. Discard the species we tried to download, and otherwise continue the search as normal. #>
	}
	
	$global:ProgressPreference = 'Continue'
} else {

	SearchForFilesBySpecies -Species $requestedSpecies <# If the user did specify an exact species they wanted to download, forego the search functions and download that species directly. #>
}

Write-Host 'Process completed.' <# End the process by letting the user know that everything went well. #>