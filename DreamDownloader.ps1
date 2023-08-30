<# There are certain names on the PokeAPI website that include
identifiers (-normal, -male, etc) that Bulbagarden doesn't use.
So, we create a List of changes to make to those names, so that
Bulbagarden CAN read them. This List is thirty-or-so names long
but that's still a lot easier than listing all 1,000 Pokemon in
the file directly. #>

$replacements = @(

	@{Name1="nidoran-f";Name2="nidoran"},
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

$pokemonCount = 1007 <# This number doesn't include Paradox Pokemon, because they have a skill issue. #>

$pokemonSearchURI = "pokeapi.co/api/v2/pokemon/" <# We start with this base web address, and we will later stick Pokemon names on the end of it to get the Pokedex entry numbers. #>

$allURI = "https://pokeapi.co/api/v2/pokemon?limit=100000&offset=0" <# We'll call this web address if and only if the user wants to download all Pokemon at once. This will get us all the names, rather than going one-by-one via index. #>

$searchClass = "fullMedia" <# In Bulbagarden's backend HTML, this is the identifier for the actual image file that it shows on a search results page. #>

$mainURI = "https://archives.bulbagarden.net/w/index.php" <# We'll call the Bulbagarden API to initiate a raw search... #>

$subURI = "?title=Special:Search&limit=500&offset=0&profile=images&search=" <# ...and we'll use these parameters while narrowing things down by Pokemon name and index. #>

$requestedSpecies = Read-Host -Prompt 'Species name (or "all")' <# Read-Host is the Console.Readline of PowerShell. #>

$requestedSpecies = $requestedSpecies.ToLower() <# PokeAPI requires that we search by names all in lowercase. #>

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 <# PowerShell requires that we set a specific security protocol (TLS12) before conducting user-level web requests. There's no need to know the underlying technology. #>

function SearchForFilesBySpecies
{
	param(

		[string]$Species <# This function takes one parameter: The name of the species the user (or script) wants to download. #>
	)

	$requestedIndex = "-1" <# Start by initializing the index to -1. If it STAYS -1, we'll know that something went wrong. #>

	try {

		$indexReq = Invoke-WebRequest -URI $pokemonSearchURI$Species <# Actually perform the web request to PokeAPI. #>

		$indexJson = $indexReq.Content | ConvertFrom-Json <# Assuming it succeeds, the result will be in JSON format; here, we convert it to a PowerShell table for easier lookup. #>

		$requestedIndex = $indexJson.id.ToString() <# Grab the Pokedex entry number, and convert it to a string. #>

		while ($requestedIndex.Length -lt 3) { <# If the index is less than 100... #>

			$requestedIndex = '0'+$requestedIndex <# ...pad it with leading 0s to comply with Bulbagarden's filename format. #>
		}
	}

	catch [System.Net.WebException] { <# If PokeAPI returns an error, that means it didn't recognize the species name. #>

		Write-Host 'Unrecognized species. Script will attempt to search regardless.' <# However, let's account for that just in case the user is searching for a newly added 'mon that PokeAPI hasn't added yet. #>

		$requestedIndex = Read-Host -Prompt 'Species index' <# Ask the user to specify the index manually. #>
	}

	$replaced = $false <# Start by assuming that the species name DOESN'T fall into the replacement table at the start of this file. #>
	foreach ($replacement in $replacements) {
		if ($Species.Equals($replacement.Name1)) {

			$Species = $replacement.Name2 <# If it does, however, then actually do the replacement. Exchange "mr-mime" for "mr. mime", etc. #>
			$replaced = $true
		}
	}

	$req = Invoke-Webrequest -URI $mainURI$subURI$requestedIndex$Species <# Now that we have our species name and our Pokedex number, make the search request to Bulbagarden. #>

	$images = $req.Images.src <# Give ourselves a short name for the web addresses to each file result. PowerShell makes this easy: In a lower-level language like C++, we'd have to iterate through each item in the List and take out the 'src' elements one at a time. But by requesting the 'src' element on the List itself, as if the List was a single object, PowerShell allows us to grab the 'src' element from all items in the List on a single line. #>

	Write-Host 'Discovered' ($images.Count - 1) 'files matching' $Species'. Saving...' <# Let the user know how many search results we found. We subtract 1 from this count because it includes a MediaWiki logo present on the search results page. #>

	foreach ($stringResult in $images) { <# Go through our search results. #>

		if (-not($stringResult.Contains("mediawiki")) -and -not($stringResult.Contains("jpg/"))) { <# We want to first make sure this isn't the MediaWiki logo previously mentioned. We also limit ourselves to PNG files, because JPG files on the archives are generally photos of merchandise; we only want artwork. #>

			$finalUri = $stringResult -replace "/thumb","" <# The results link us to thumbnail images scaled down to 120px. We can get the full-sized image URL by manipulating it. First we remove the thumbnail indicator... #> -replace "png/.*","png" <# ...and then we remove the suffix that normally dictates the size of the thumbnail. #>

			$finalName = $finalUri -replace ".*/" <# Grab the file's actual name by removing the rest of the web address. #>

			$fileReq = Invoke-Webrequest $finalUri -OutFile $finalName <# Finally, now that we have the file name and address, call a web request directly to the file, and save it locally. #>
		}
	}
}

if ($requestedSpecies.Equals('all')) { <# Ask the user if they want to download all species images indiscriminately. #>

	$restart = Read-Host -Prompt 'Start from a specific species in the list? (y/n)' <# In case the script was previously ended prematurely, ask the user if they'd like to start from where they left off. #>

	$specResume = ' ' <# Start by assuming the user doesn't want to do that. #>
	$beginScanning = $true

	if ($restart -eq 'y') { <# If they do... #>
		$beginScanning = $false

		$specResume = Read-Host -Prompt 'Species to begin from' <# ...ask them where exactly their starting point will be. #>
		$specResume = $specResume.ToLower()
	}

	$doReplaces = Read-Host -Prompt "Scan for regex replacement names? If you don't know what this means, you don't need it. (y/n)" <# This WAS something I inserted so that Miles (my beta tester) would be able to download specifically only the species in the replacement List at the start of the file. I could've removed it afterwards, but I felt like there might still be niche instances where it's useful. #>
	if ($doReplaces -eq 'y') {
		foreach ($replacement in $replacements) {

			SearchForFilesBySpecies -Species $replacement.Name1 <# If, for some reason, the user does want to do just that, then do it: Conduct the search for all species in the List. #>
		}
	}

	$indexReq = Invoke-WebRequest -URI $allURI <# Whether or not the regex names were downloaded, we now begin our search proper. Begin by downloading all Pokemon names from PokeAPI. The specific function we're calling will give us not just the names, but further search URLs that we can plug right back into PokeAPI to get the indexes. #>

	$result = $indexReq.Content | ConvertFrom-Json <# Convert the names to a table. #>

	$results = $result.results <# Give the result a non-redundant name. #>
	$countedPokemon = 0

	foreach ($resource in $results) { <# For every result in the List... #>
		try {

			$indexReq = Invoke-WebRequest -URI $resource.url <# ...call the associated search URL... #>

			$indexJson = $indexReq.Content | ConvertFrom-Json <# ...and as always, convert it to a table. #>

			if ($indexJson.name -eq $specResume) { <# Check if the user specified a starting point earlier. #>

				$beginScanning = $true <# If they did, and this species matches that starting point, then let the script know to start downloading. #>
			}

			if ($beginScanning) { <# If and only if we've been given that prior go-ahead or we're downloading everything... #>

				SearchForFilesBySpecies -Species $indexJson.name <# ...call our custom download function. #>
			}

			$countedPokemon = $countedPokemon+1 <# Increase the counter of species we've downloaded. #>

			if ($countedPokemon -gt $pokemonCount) { <# If the counter has reached the Paradox Pokemon... #>

				return <# ...halt the search, because we don't want them. #>
			}
		}

		catch [System.Net.WebException] { } <# If an error occurs, do not halt the script. Discard the species we tried to download, and otherwise continue the search as normal. #>
	}
} else {

	SearchForFilesBySpecies -Species $requestedSpecies <# If the user did specify an exact species they wanted to download, forego the search functions and download that species directly. #>
}

Write-Host 'Process completed.' <# End the process by letting the user know that everything went well. #>