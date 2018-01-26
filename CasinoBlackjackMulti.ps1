# Settings/options/variables:

# Max players (not including dealer)
$MaxPlayers = 4
# Money each player starts with
$StartingMoney = 2000
# Money dealer starts with
$CasinoBank = 1000000000

# $CasinoBank is the default integer type (32-bit signed) which will only allow a max value
# of 2147483647. If you want to increase it beyond that you will need to use a cast operator:
#  - [uint32] (32-bit unsigned integer) - Max. value = 4294967295
#  - [int64] (64-bit signed integer) - Max. value = 9223372036854775807
#  - [uint64] (64-bit unsigned integer) - Max. value = 18446744073709551615

# Minimum bet player can place
$OverallMinimumBet = 2
# Maximum bet player can place
$OverallMaximumBet = 500
# No maximum bet (overrides dynamic bet scaling) - If true max bet is entire wallet
$NoMaxBet = $False
# Dynamic bet scaling - If true max bet is 1/$BetScale of wallet when wallet > ($ScaleStart x $OverallMaximumBet)
$DynamicBetScaling = $True
$BetScale = 4
$ScaleStart = 4

# Auto stand (overrides force stand) - If true player auto-stands where hand = 21 (incl. where hand = both 11 & 21)
$AutoStand = $False
# Force stand - If true player cannot throw hand of 21 (i.e. cannot hit) except where hand = both 11 & 21
$ForceStand = $True

# Number of decks used
$NumberOfDecks = 6
# Rounds to play before cards are reshuffled
$ShuffleLimit = 15
# Console output delay (ms)
$MessageDelay = 600
# Custom name character limit
$CharacterLimit = 30
# Custom name whitespace control - If true names cannot contain two consecutive whitespace characters or start/end with them
$WhiteSpaceControl = $True

# Console output colours:

# Title/Player
$TitleColour = "Cyan"
# Move/Action
$ActionColour = "Cyan"
# Successful bet
$MoneyGainColour = "Green"
# Equal bet
$MoneyEqualColour = "Yellow"
# Unsuccessful bet
$MoneyLossColour = "Red"
# Unaccepted input
$ExInputColour = "Yellow"

# To try and maintain consistency with Powershell defaults
# the following colours are automatically set by OS version::

# Hands & hand values
$CurrentHandColour = "White"
# Player options
$OptionsColour = "White"
# Initial/split deals
$DealColour = "White"

# Change to False to override automatic colours & use above
$CheckOSVersion = $True

# Set automatic and default colours
If ($CheckOSVersion) {
    $OSVersion = (Get-WmiObject -Class Win32_OperatingSystem -ErrorAction SilentlyContinue).Version
    If (($OSVersion -like "10*") -or ($OSVersion -like "6.3*") -or ($OSVersion -like "6.2*")) {
        $CurrentHandColour = "White"
        $OptionsColour = "White"
        $DealColour = "White"
    }
    Elseif (($OSVersion -like "6.1*") -or ($OSVersion -like "6.0*") -or ($OSVersion -like "5.2*") -or ($OSVersion -like "5.1*")) {
        $CurrentHandColour = "Gray"
        $OptionsColour = "Gray"
        $DealColour = "Gray"
    }
    Else {
        $CurrentHandColour = "White"
        $OptionsColour = "White"
        $DealColour = "White"
    }
}

# Suits & Numbers in Unicode
$Suits = [char]0x2660,[char]0x2663,[char]0x2665,[char]0x2666
$Numbers = [char]0x0041,[char]0x0032,[char]0x0033,[char]0x0034,[char]0x0035,[char]0x0036,[char]0x0037,[char]0x0038,[char]0x0039,([char]0x0031+[char]0x0030),[char]0x004A,[char]0x0051,[char]0x004B

# Hash table of cards to number values
$CardValues = @{}
Foreach ($Suit in $Suits) {
	Foreach ($Number in $Numbers) {
        Try {$IntValue = [convert]::ToInt32($Number, 10)}
        Catch [FormatException] {
            Switch ($Number) {
                "A" {$IntValue = 11}
                "J" {$IntValue = 10}
                "Q" {$IntValue = 10}
                "K" {$IntValue = 10}
            }
        }
        $CardValues.($Number+$Suit) = $IntValue
    }
}

# Define functions

# Shuffle deck
Function Shuffle-Deck {
    $PreShuffle = @()
    $Script:Cards = New-Object System.Collections.ArrayList
    # Create decks
    For ($DeckCount = 1; $DeckCount -le $NumberOfDecks; $DeckCount++) {
        Foreach ($Suit in $Suits) {
	        Foreach ($Number in $Numbers) {$PreShuffle += $Number+$Suit}
	    }
    }
    # Shuffle cards
    $PostShuffle = $PreShuffle | Sort-Object {Get-Random}
    Foreach ($Entry in $PostShuffle) {[void]$Script:Cards.Add($Entry)}
}

# Get player hands
Function Get-PlayerHands {
    $DisplayCardsTable = @()
    $BiggestHandTable = @()
    # Determine biggest hand
    Foreach ($Participant in $Script:PlayerList) {
        If (($BustedTable.$Participant -ne $True) -and ($BlackjackTable.$Participant -ne $True)) {
            If ($PlayerSplit.$Participant -eq $True) {
                $HandList = Get-Variable SplitList$Participant -ValueOnly
                Foreach ($Item in $HandList) {
                    $Hand = Get-Variable $Item -ValueOnly
                    $BiggestHandTable += $Hand.Count
                }
            }
            Else {
                $Hand = Get-Variable $Participant -ValueOnly
                $BiggestHandTable += $Hand.Count
            }
        }
    }
    $NumberOfIterations = ($BiggestHandTable | Measure -Maximum).Maximum
    Foreach ($Participant in $Script:PlayerList) {
        If (($BustedTable.$Participant -ne $True) -and ($BlackjackTable.$Participant -ne $True)) {
            # Player split
            If ($PlayerSplit.$Participant -eq $True) {
                $HandList = Get-Variable SplitList$Participant -ValueOnly
                Foreach ($Item in $HandList) {
                    If (($SplitBusted.$Item -ne $True) -and ($SplitBlackjack.$Item -ne $True)) {
                        $SplitCards = Get-Variable $Item -ValueOnly
                        $NumberOfCards = $SplitCards.Count
                        $PlayerHandName = ($PlayerNames.$Participant)+(" Split")
                        $CardsObject = New-Object PsObject
                        $CardsObject | Add-Member -MemberType NoteProperty -Name "Player Hand" -Value $PlayerHandName
                        For ($Iteration = 0; $Iteration -lt $NumberOfIterations; $Iteration++) {
                            $CardName = $Iteration+1
                            If (($CardName -eq 3) -and ($SplitDouble.$Item -eq $True)) {$CardValue = '???'}
                            Elseif ($CardName -gt $NumberOfCards) {$CardValue = '-'}
                            Else {[string]$CardValue = $SplitCards[$Iteration]}
                            $CardsObject | Add-Member -MemberType NoteProperty -Name "Card $CardName" -Value $CardValue
                        }
                        $DisplayCardsTable += $CardsObject
                    }
                }
            }
            # Player did not split
            Else {
                $Hand = Get-Variable $Participant -ValueOnly
                $NumberOfCards = $Hand.Count
                $PlayerHandName = ($PlayerNames.$Participant)+(" Main")
                $CardsObject = New-Object PsObject
                $CardsObject | Add-Member -MemberType NoteProperty -Name "Player Hand" -Value $PlayerHandName
                For ($Iteration = 0; $Iteration -lt $NumberOfIterations; $Iteration++) {
                    $CardName = $Iteration+1
                    If ((($CardName -eq 2) -and ($Participant -eq "Dealer")) -or (($CardName -eq 3) -and ($PlayerDouble.$Participant -eq $True))) {$CardValue = '???'}
                    Elseif ($CardName -gt $NumberOfCards) {$CardValue = '-'}
                    Else {[string]$CardValue = $Hand[$Iteration]}
                    $CardsObject | Add-Member -MemberType NoteProperty -Name "Card $CardName" -Value $CardValue
                }
                $DisplayCardsTable += $CardsObject
            }
        }
    }
    $DisplayCardsTable | Format-Table -AutoSize
}

# Get bets
Function Get-PlayerBets {
    $DisplayBetsTable = @()
    Foreach ($Participant in $Script:PlayerList) {
        If ($Participant -ne "Dealer") {
            $PlayerBetTotal = $PlayerBetTable.$Participant
            $BetsObject = New-Object PsObject
            $BetsObject | Add-Member -MemberType NoteProperty -Name "Player" -Value $PlayerNames.$Participant
            $BetsObject | Add-Member -MemberType NoteProperty -Name "Wallet" -Value $PlayerWallets.$Participant
            If ($PlayerSplit.$Participant -eq $True) {
                $BetsObject | Add-Member -MemberType NoteProperty -Name "Main Bet" -Value 0
                $PlayerBetTotal = 0
            }
            Else {$BetsObject | Add-Member -MemberType NoteProperty -Name "Main Bet" -Value $PlayerBetTable.$Participant}
            If ($InsuranceTrigger.$Participant -eq $True) {
                $BetsObject | Add-Member -MemberType NoteProperty -Name "Insurance" -Value $InsuranceBetTable.$Participant
                $PlayerBetTotal += $InsuranceBetTable.$Participant
            }
            Else {$BetsObject | Add-Member -MemberType NoteProperty -Name "Insurance" -Value 0}
            If ($PlayerDouble.$Participant -eq $True) {
                $BetsObject | Add-Member -MemberType NoteProperty -Name "Double" -Value $PlayerBetTable.$Participant
                $PlayerBetTotal += $PlayerBetTable.$Participant
            }
            Else {$BetsObject | Add-Member -MemberType NoteProperty -Name "Double" -Value 0}
            If ($PlayerSplit.$Participant -eq $True) {
                $SplitBetTotal = 0
                $HandList = Get-Variable SplitList$Participant -ValueOnly
                Foreach ($Item in $HandList) {
                    If (($SplitBusted.$Item -ne $True) -and ($SplitBlackjack.$Item -ne $True)) {
                        If ($SplitDouble.$Item -eq $True) {$SplitBetTotal += ($PlayerBetTable.$Participant)*2}
                        Else {$SplitBetTotal += $PlayerBetTable.$Participant}
                    }
                }
                $BetsObject | Add-Member -MemberType NoteProperty -Name "Split" -Value $SplitBetTotal
                $PlayerBetTotal += $SplitBetTotal
            }
            Else {$BetsObject | Add-Member -MemberType NoteProperty -Name "Split" -Value 0}
            $BetsObject | Add-Member -MemberType NoteProperty -Name "Total" -Value $PlayerBetTotal
            $DisplayBetsTable += $BetsObject
        }
    }
    $DisplayBetsTable | Format-Table -AutoSize
}

# Get player options
Function Get-PlayerOptions {
    Param ($Choices, $NameOfPlayer, $CardsInHand, $ValueOfHand, $SplitActive, $SplitNumber)
    Write-Host
    If ($SplitActive -eq $True) {
        Write-Host "$NameOfPlayer split $SplitNumber hand: $CardsInHand" -ForegroundColor $CurrentHandColour
        Write-Host "$NameOfPlayer split $SplitNumber hand value: $ValueOfHand" -ForegroundColor $CurrentHandColour
    }
    Else {
        Write-Host "$NameOfPlayer hand: $CardsInHand" -ForegroundColor $CurrentHandColour
        Write-Host "$NameOfPlayer hand value: $ValueOfHand" -ForegroundColor $CurrentHandColour
    }
    Start-Sleep -Milliseconds $MessageDelay
    Write-Host
    Write-Host "The following options are available:" -ForegroundColor $OptionsColour
    Write-Host
    Write-Host " - Options (Display this message)" -ForegroundColor $OptionsColour
    Write-Host " - Cards (Show active hands)" -ForegroundColor $OptionsColour
    Write-Host " - Bets (Show active bets)" -ForegroundColor $OptionsColour
    Foreach ($Item in $Choices) {Write-Host " - $Item" -ForegroundColor $OptionsColour}
    Write-Host
}

# Get active players
Function Get-ActivePlayers {
    # Check split players have hands
    If ($PlayerSplit.ContainsValue($True)) {
        $SplitHandCount = 0
        Foreach ($HumanPlayer in $Script:PlayerList) {
            If (($HumanPlayer -ne "Dealer") -and ($PlayerSplit.$HumanPlayer -eq $True)) {
                $SplitHandTest = Get-Variable SplitList$HumanPlayer -ValueOnly
                $SplitHandCount += $SplitHandTest.Count
            }
        }
        If ($SplitHandCount -eq 0) {$ActiveSplitHands = $False}
        Else {$ActiveSplitHands = $True}
    }
    Else {$ActiveSplitHands = $False}
    # Check if players bust/blackjack/split
    $ActivePlayers = @{}
    Foreach ($HumanPlayer in $Script:PlayerList) {
        If ($HumanPlayer -ne "Dealer") {
            If (($BustedTable.$HumanPlayer -eq $True) -or ($BlackjackTable.$HumanPlayer -eq $True) -or ($PlayerSplit.$HumanPlayer -eq $True)) {$ActivePlayers.$HumanPlayer = $False}
            Else {$ActivePlayers.$HumanPlayer = $True}
        }
    }
    If (($ActivePlayers.ContainsValue($True)) -or ($ActiveSplitHands)) {$Script:HandsInPlay = $True}
    Else {$Script:HandsInPlay = $False}
}

# Get hand value
Function Get-HandValue {
    Param ($CurrentCards)
    $AceCount = 0
    $NonAceHandValue = 0
    $Script:PlayerHandValue = $Null
    $Script:DisplayHand = $Null
    $Script:DisplayHandValue = $Null
    # Count Aces & sum non-Aces
    Foreach ($Card in $CurrentCards) {
        [string]$Script:DisplayHand += "$Card "
        If ($Card[0] -eq "A") {$AceCount += 1}
        Else {$NonAceHandValue = $NonAceHandValue + ($CardValues.$Card)}
    }
    # Determine hand value
    $Script:LowAceValue = 0
    If ($AceCount -gt 0) {
        $StartValue = $AceCount+$NonAceHandValue
        If ($StartValue -le 21) {
            [string]$Script:DisplayHandValue += "$StartValue"
            $AcePossibleAsc = @($AceCount)
            $AceCountRange = 1..$AceCount
            Foreach ($Item in $AceCountRange) {
                $PossibleValue = ($Item*10)+$AceCount
                $AcePossibleAsc += $PossibleValue
                $TestDisplayValue = ($PossibleValue+$NonAceHandValue)
                If ($TestDisplayValue -le 21) {[string]$Script:DisplayHandValue += ", $TestDisplayValue"}
            }
            $AcePossibleDesc = $AcePossibleAsc | Sort-Object -Descending
            $Script:LowAceValue = $StartValue
            $TestCounter = 0
            $Script:PlayerHandValue = ($AcePossibleDesc[$TestCounter])+$NonAceHandValue
            While ($Script:PlayerHandValue -gt 21) {
                $TestCounter = $TestCounter+1
                $Script:PlayerHandValue = ($AcePossibleDesc[$TestCounter])+$NonAceHandValue
            }
        }
        Else {
            $Script:PlayerHandValue = $StartValue
            $Script:DisplayHandValue = $StartValue
        }
    }
    Else {
        $Script:PlayerHandValue = $NonAceHandValue
        $Script:DisplayHandValue = $NonAceHandValue
    }
}

Write-Host "-------------------------" -ForegroundColor $TitleColour
Write-Host "Welcome to"([char]0x2660)"Blackjack!"([char]0x2660) -ForegroundColor $TitleColour
Write-Host "-------------------------" -ForegroundColor $TitleColour

# Start set up
$MaxPlayersRange = 1..$MaxPlayers
$QuitValue = $False
While ($QuitValue -ne $True) {
    $PlayGame = $True
    $ShuffleCount = 0
    $RoundCount = 0
    $Script:PlayerList = New-Object System.Collections.ArrayList
    $PlayerNames = @{}
    $PlayerWallets = @{}
    # Prompt number of players
    Write-Host
    $InputPlayerNumber = $Null
    While ($MaxPlayersRange -notcontains $InputPlayerNumber) {
        $InputPlayerNumber = Read-Host "How many Players?(1-$MaxPlayers)"
        Try {$NumberOfPlayers = [convert]::ToInt32($InputPlayerNumber, 10)}
        Catch [FormatException] {
            Write-Host
            Write-Host "Please enter an integer" -ForegroundColor $ExInputColour
            Write-Host
            $ExValue = $True
        }
        Catch [ArgumentOutOfRangeException] {
            Write-Host
            Write-Host "Please enter a value" -ForegroundColor $ExInputColour
            Write-Host
            $ExValue = $True
        }
        Catch [OverflowException] {
            Write-Host
            Write-Host "Please enter a number in the specified range" -ForegroundColor $ExInputColour
            Write-Host
            $ExValue = $True
        }
        Finally {
            If (($MaxPlayersRange -notcontains $InputPlayerNumber) -and ($ExValue -ne $True)) {
                Write-Host
                Write-Host "Please enter a number in the specified range" -ForegroundColor $ExInputColour
                Write-Host
            }
            $ExValue = $False
        }
    }
    # Create empty hand for each player
    For ($AppendNumber = 1; $AppendNumber -le $NumberOfPlayers; $AppendNumber++) {
        New-Variable -Name Player$AppendNumber -Value (New-Object System.Collections.ArrayList) -ErrorAction SilentlyContinue
        [void]$PlayerList.Add('Player'+$AppendNumber)
    }
    # Assign names
    Write-Host
    $NamePrompt = $Null
    While ("Y","YES","N","NO" -notcontains $NamePrompt) {$NamePrompt = (Read-Host "Do you want to assign custom names?(Y/N)").ToUpper()}
    If ("Y","YES" -contains $NamePrompt) {
        Write-Host
        Write-Host "Character limit: $CharacterLimit"
        Start-Sleep -Milliseconds $MessageDelay
        Foreach ($Player in $Script:PlayerList) {
            Write-Host
            $NameSuccessful = $False
            While ($NameSuccessful -ne $True) {
                $Name = Read-Host "Name for $Player"
                # No input
                If ([String]::IsNullOrEmpty($Name)) {
                    Write-Host
                    Write-Host "Please enter a name for $Player" -ForegroundColor $ExInputColour
                    Write-Host
                }
                # Get creative with whitespace control as v2 does not support [String]::IsNullOrWhiteSpace($Str) static method
                Elseif (($WhiteSpaceControl) -and (($Name -like " *") -or ($Name -like "* ") -or ($Name -like "*  *"))) {
                    # Name starts/ends with whitespace
                    If (($Name -like " *") -or ($Name -like "* ")) {
                    Write-Host
                    Write-Host "Name cannot start or end with whitespace" -ForegroundColor $ExInputColour
                    Write-Host
                    }
                    # Name has two or more consecutive whitespace characters
                    Elseif ($Name -like "*  *") {
                        Write-Host
                        Write-Host "Name cannot have two or more consecutive whitespace characters" -ForegroundColor $ExInputColour
                        Write-Host
                    }
                }
                # Over character limit
                Elseif ($Name.Length -gt $CharacterLimit) {
                    Write-Host
                    Write-Host "Name exceeds the character limit of $CharacterLimit" -ForegroundColor $ExInputColour
                    Write-Host
                }
                Else {$NameSuccessful = $True}
            }
            $PlayerNames.$Player = $Name
        }
    }
    Else {Foreach ($Player in $Script:PlayerList) {$PlayerNames.$Player = $Player}}
    # Create wallets
    Foreach ($Player in $Script:PlayerList) {$PlayerWallets.$Player = $StartingMoney}
    # Create dealer
    $Dealer = New-Object System.Collections.ArrayList
    [void]$PlayerList.Add("Dealer")
    $PlayerNames."Dealer" = "Dealer"
    $DealerWallet = $CasinoBank
    # Start game
    While ($PlayGame) {
        $PlayerBetTable = @{}
        $InsuranceTrigger = @{}
        $InsuranceBetTable = @{}
        $PlayerDouble = @{}
        $PlayerSplit = @{}
        $SplitAces = @{}
        $SplitDouble = @{}
        $SplitBlackjack = @{}
        $SplitBusted = @{}
        $BlackjackTable = @{}
        $BustedTable = @{}
        $MoveFinished = @{}
        $DealerBlackjack = $False
        $DealerBusted = $False
        $EndRound = $False
        Foreach ($Player in $Script:PlayerList) {
            $MoveFinished.$Player = $False
            If ($Player -ne "Dealer") {
                $PlayerSplit.$Player = $False
                $PlayerDouble.$Player = $False
                $InsuranceTrigger.$Player = $False
                $BustedTable.$Player = $False
                $BlackjackTable.$Player = $False
            }
        }
        If ($ShuffleCount -eq 0) {
            Write-Host
            Write-Host "Shuffling cards..."
            Start-Sleep -Milliseconds $MessageDelay
            Shuffle-Deck
        }
        Elseif ($ShuffleCount -eq $ShuffleLimit) {
            Write-Host
            Write-Host "$ShuffleLimit rounds played, shuffling cards..."
            Start-Sleep -Milliseconds $MessageDelay
            Shuffle-Deck
            $ShuffleCount = 0
        }
        $ShuffleCount += 1
        $RoundCount += 1
        $RoundCountLength = ([string]$RoundCount).Length
        $RoundTitleLines = ("-")*(6+$RoundCountLength)
        Write-Host
        Write-Host $RoundTitleLines -ForegroundColor $TitleColour
        Write-Host "Round $RoundCount" -ForegroundColor $TitleColour
        Write-Host $RoundTitleLines -ForegroundColor $TitleColour
        Write-Host
        Start-Sleep -Milliseconds $MessageDelay
        # Take bets
        Foreach ($Player in $Script:PlayerList) {
            If ($Player -ne "Dealer") {
                If ($NoMaxBet) {$MaxBet = $PlayerWallets.$Player}
                Elseif ($DynamicBetScaling) {
                    If (($PlayerWallets.$Player) -gt ($ScaleStart*$OverallMaximumBet)) {[int]$MaxBet = ($PlayerWallets.$Player)/$BetScale}
                    Elseif ($PlayerWallets.$Player -lt $OverallMaximumBet) {$MaxBet = $PlayerWallets.$Player}
                    Else {$MaxBet = $OverallMaximumBet}
                }
                Else {
                    If ($PlayerWallets.$Player -lt $OverallMaximumBet) {$MaxBet = $PlayerWallets.$Player}
                    Else {$MaxBet = $OverallMaximumBet}
                }
                $InputBetNumber = $Null
                While ($OverallMinimumBet..$MaxBet -notcontains $InputBetNumber) {
                    Write-Host $PlayerNames.$Player "money:" $PlayerWallets.$Player
                    $InputBetNumber = Read-Host $PlayerNames.$Player "your bet? (Min:`$$OverallMinimumBet, Max:`$$MaxBet)"
                    Try {$PlayerBet = [convert]::ToInt32($InputBetNumber, 10)}
                    Catch [FormatException] {
                        Write-Host
                        Write-Host $PlayerNames.$Player "please enter an integer" -ForegroundColor $ExInputColour
                        Write-Host
                        $ExValue = $True
                    }
                    Catch [ArgumentOutOfRangeException] {
                        Write-Host
                        Write-Host $PlayerNames.$Player "please enter a value" -ForegroundColor $ExInputColour
                        Write-Host
                        $ExValue = $True
                    }
                    Catch [OverflowException] {
                        Write-Host
                        Write-Host $PlayerNames.$Player "please enter a number in the bet range" -ForegroundColor $ExInputColour
                        Write-Host
                        $ExValue = $True
                    }
                    Finally {
                        If (($OverallMinimumBet..$MaxBet -notcontains $InputBetNumber) -and ($ExValue -ne $True)) {
                            Write-Host
                            Write-Host $PlayerNames.$Player "please enter a number in the bet range" -ForegroundColor $ExInputColour
                            Write-Host
                        }
                        $ExValue = $False
                    }
                }
            # Update wallet
            $PlayerBetTable.$Player = $PlayerBet
            $PlayerWallets.$Player = ($PlayerWallets.$Player)-$PlayerBet
            Write-Host
            Write-Host $PlayerNames.$Player "places a bet of $PlayerBet" -ForegroundColor $ActionColour
            Write-Host
            }
        }
        # Initial deal
        Write-Host "Dealing cards..."
        Write-Host
        For ($InitialDeal = 1; $InitialDeal -le 2; $InitialDeal++) {
            Foreach ($Player in $Script:PlayerList) {
                Start-Sleep -Milliseconds $MessageDelay
                $CurrentHand = Get-Variable $Player -ValueOnly
                [void]$CurrentHand.Add($Script:Cards[0])
                Set-Variable $Player -Value $CurrentHand
                If (($Player -eq "Dealer") -and ($InitialDeal -eq 2)) {$CardDealt = "???"}
                Else {$CardDealt = $Script:Cards[0]}
                Write-Host $PlayerNames.$Player "is dealt $CardDealt" -ForegroundColor $DealColour
                $Script:Cards.RemoveAt(0)
            }
        }
        # Offer insurance bet if dealer face up is Ace
        If ($Dealer[0][0] -eq "A") {
            Write-Host
            Write-Host "Dealers face up card is Ace"
            Start-Sleep -Milliseconds $MessageDelay
            $InsurancePrompt = $Null
            While ("Y","YES","N","NO" -notcontains $InsurancePrompt) {$InsurancePrompt = (Read-Host "Do any players want to make insurance bets?(Y/N)").ToUpper()}
            If ("Y","YES" -contains $InsurancePrompt) {
                Foreach ($Player in $Script:PlayerList) {
                    If ($Player -ne "Dealer") {
                        $InsuranceTrigger.$Player = $True
                        # Check player wallet has money
                        If ($PlayerWallets.$Player -gt 0) {
                            [int]$HalfCurrentBet = ($PlayerBetTable.$Player)/2
                            # Max insurance bet is half current bet or total wallet (whichever is lower)
                            If ($PlayerWallets.$Player -lt $HalfCurrentBet) {$InsuranceBetMax = $PlayerWallets.$Player}
                            Else {$InsuranceBetMax = $HalfCurrentBet}
                            $InsuranceBetRange = 0..$InsuranceBetMax
                            $InsuranceBetPrompt = $Null
                            While ($InsuranceBetRange -notcontains $InsuranceBetPrompt) {
                                Write-Host
                                Write-Host $PlayerNames.$Player "money:" $PlayerWallets.$Player
                                $InsuranceBetPrompt = Read-Host $PlayerNames.$Player "your insurance bet? (Min:`$0, Max:`$$InsuranceBetMax)"
                                Try {$InsuranceBet = [convert]::ToInt32($InsuranceBetPrompt, 10)}
                                Catch [FormatException] {
                                    Write-Host
                                    Write-Host $PlayerNames.$Player "please enter an integer" -ForegroundColor $ExInputColour
                                    $InsuranceBetPrompt = $Null
                                    $ExValue = $True
                                }
                                Catch [ArgumentOutOfRangeException] {
                                    Write-Host
                                    Write-Host $PlayerNames.$Player "please enter a value" -ForegroundColor $ExInputColour
                                    $InsuranceBetPrompt = $Null
                                    $ExValue = $True
                                }
                                Catch [OverflowException] {
                                    Write-Host
                                    Write-Host $PlayerNames.$Player "please enter a number in the bet range" -ForegroundColor $ExInputColour
                                    $InsuranceBetPrompt = $Null
                                    $ExValue = $True
                                }
                                Finally {
                                    If (($InsuranceBetRange -notcontains $InsuranceBetPrompt) -and ($ExValue -ne $True)) {
                                        Write-Host
                                        Write-Host $PlayerNames.$Player "please enter a number in the bet range" -ForegroundColor $ExInputColour
                                        $InsuranceBetPrompt = $Null
                                    }
                                    $ExValue = $False
                                }
                            }
                            # If 0 no insurance bet
                            If ($InsuranceBet -eq 0) {
                                $InsuranceTrigger.$Player = $False
                                Write-Host
                                Write-Host $PlayerNames.$Player "did not make an insurance bet" -ForegroundColor $ActionColour
                            }
                            # Else update wallet with bet
                            Else {
                                $InsuranceBetTable.$Player = $InsuranceBet
                                $PlayerWallets.$Player = ($PlayerWallets.$Player)-$InsuranceBet
                                Write-Host
                                Write-Host $PlayerNames.$Player "made an insurance bet of $InsuranceBet" -ForegroundColor $ActionColour
                            }
                        }
                        # Not enough money for insurance bet
                        Else {
                            Write-Host
                            Write-Host $PlayerNames.$Player "has no money to make an insurance bet!" -ForegroundColor $ActionColour
                            $InsuranceTrigger.$Player = $False
                        }
                    }
                }
            }
            Elseif ("N","NO" -contains $InsurancePrompt) {
                Foreach ($Player in $Script:PlayerList) {$InsuranceTrigger.$Player = $False}
            }
        }
        # Check for dealer blackjack if face up is Ace or 10-card
        If (($Dealer[0][0] -eq "A") -or ($CardValues.($Dealer[0]) -eq 10)) {
            Start-Sleep -Milliseconds $MessageDelay
            Write-Host
            Write-Host "Dealers face up card is" $Dealer[0] "- Checking for blackjack..."
            # Dealer has blackjack
            If ((($CardValues.($Dealer[0]))+($CardValues.($Dealer[1]))) -eq 21) {
                Start-Sleep -Milliseconds $MessageDelay
                Write-Host "Dealers second card is" $Dealer[1] "- Dealer has blackjack!"
                $DealerBlackjack = $True
                $EndRound = $True
                Foreach ($Player in $Script:PlayerList) {
                    If ($Player -ne "Dealer") {
                        Write-Host
                        $PlayerHand = Get-Variable $Player -ValueOnly
                        # Player also has blackjack
                        If ((($CardValues.($PlayerHand[0]))+($CardValues.($PlayerHand[1]))) -eq 21) {
                            $BlackjackTable.$Player = $True
                            Start-Sleep -Milliseconds $MessageDelay
                            Write-Host $PlayerNames.$Player "hand -" $PlayerHand[0] $PlayerHand[1]
                            Write-Host $PlayerNames.$Player "also has blackjack!"
                            $PlayerWallets.$Player = ($PlayerWallets.$Player+$PlayerBetTable.$Player)
                            Start-Sleep -Milliseconds $MessageDelay
                            Write-Host
                            Write-Host $PlayerNames.$Player "receives back their bet of" $PlayerBetTable.$Player -ForegroundColor $MoneyEqualColour
                            $PlayerBetTable.$Player = 0
                        }
                        # Player does not have blackjack
                        Else {
                            Start-Sleep -Milliseconds $MessageDelay
                            Write-Host $PlayerNames.$Player "hand -" $PlayerHand[0] $PlayerHand[1]
                            Write-Host $PlayerNames.$Player "does not have blackjack"
                            $DealerWallet = ($DealerWallet+$PlayerBetTable.$Player)
                            Start-Sleep -Milliseconds $MessageDelay
                            Write-Host
                            Write-Host "Dealer collects bet of" $PlayerBetTable.$Player "from" $PlayerNames.$Player -ForegroundColor $MoneyLossColour
                            $PlayerBetTable.$Player = 0
                        }
                        # Payout any insurance bets
                        If ($InsuranceTrigger.$Player -eq $True) {
                            $InsurancePayout = ($InsuranceBetTable.$Player)*2
                            Start-Sleep -Milliseconds $MessageDelay
                            Write-Host
                            Write-Host $PlayerNames.$Player "made an insurance bet of" $InsuranceBetTable.$Player
                            $PlayerWallets.$Player = ($PlayerWallets.$Player)+$InsurancePayout
                            $DealerWallet = $DealerWallet-($InsuranceBetTable.$Player)
                            Start-Sleep -Milliseconds $MessageDelay
                            Write-Host
                            Write-Host $PlayerNames.$Player "receives an insurance payout of $InsurancePayout" -ForegroundColor $MoneyGainColour
                            $InsuranceBetTable.$Player = 0
                        }
                    }
                }
            }
            # Dealer does not have blackjack
            Else {
                Start-Sleep -Milliseconds $MessageDelay
                Write-Host "Dealer does not have blackjack"
            }
        }
        # Start player/dealer turns
        While ($EndRound -ne $True) {
            Foreach ($Player in $Script:PlayerList) {
                Get-ActivePlayers
                # Dealer moves
                If (($Player -eq "Dealer") -and $Script:HandsInPlay) {
                    Write-Host
                    Write-Host "------------" -ForegroundColor $TitleColour
                    Write-Host "Dealers turn" -ForegroundColor $TitleColour
                    Write-Host "------------" -ForegroundColor $TitleColour
                    While ($MoveFinished."Dealer" -ne $True) {
                        Get-HandValue -CurrentCards $Dealer
                        Start-Sleep -Milliseconds $MessageDelay
                        If ($Dealer.Count -eq 2) {
                            Write-Host
                            Write-Host "Dealer turns over second card to reveal" $Dealer[1] -ForegroundColor $ActionColour
                            Start-Sleep -Milliseconds $MessageDelay
                        }
                        Write-Host
                        Write-Host "Dealers hand: $Script:DisplayHand" -ForegroundColor $CurrentHandColour
                        Write-Host "Dealers hand value: $Script:DisplayHandValue" -ForegroundColor $CurrentHandColour
                        Write-Host
                        # Dealer busted
                        If ($Script:PlayerHandValue -gt 21) {
                            Start-Sleep -Milliseconds $MessageDelay
                            Write-Host "Dealer is bust!"
                            Start-Sleep -Milliseconds $MessageDelay
                            $DealerBusted = $True
                            $MoveFinished."Dealer" = $True
                        }
                        # Dealer not busted
                        Else {
                            # Dealer stands
                            If (($Script:PlayerHandValue -ge 17) -and ($Script:PlayerHandValue -le 21)) {
                                Start-Sleep -Milliseconds $MessageDelay
                                Write-Host "Dealer stands on $Script:PlayerHandValue" -ForegroundColor $ActionColour
                                $Script:DealerStandValue = $Script:PlayerHandValue
                                $MoveFinished."Dealer" = $True
                            }
                            # Dealer hits
                            Elseif ($Script:PlayerHandValue -lt 17) {
                                Start-Sleep -Milliseconds $MessageDelay
                                Write-Host "Dealer hits and is dealt" $Script:Cards[0] -ForegroundColor $ActionColour
                                [void]$Dealer.Add($Script:Cards[0])
                                $Script:Cards.RemoveAt(0)
                            }
                        }
                    }
                }
                # Player moves
                Elseif ($Player -ne "Dealer") {
                    $NameTitleLines = ("-")*((($PlayerNames.$Player).Length)+18)
                    Start-Sleep -Milliseconds $MessageDelay
                    Write-Host
                    Write-Host $NameTitleLines -ForegroundColor $TitleColour
                    Write-Host $PlayerNames.$Player "- It is your turn" -ForegroundColor $TitleColour
                    Write-Host $NameTitleLines -ForegroundColor $TitleColour
                    $PlayerHand = Get-Variable $Player -ValueOnly
                    While ($MoveFinished.$Player -ne $True) {
                        # Player has blackjack
                        If (($PlayerHand.Count -eq 2) -and ((($CardValues.($PlayerHand[0]))+($CardValues.($PlayerHand[1]))) -eq 21)) {
                            Start-Sleep -Milliseconds $MessageDelay
                            Write-Host
                            Write-Host $PlayerNames.$Player "hand -" $PlayerHand[0] $PlayerHand[1] -ForegroundColor $CurrentHandColour
                            Start-Sleep -Milliseconds $MessageDelay
                            Write-Host $PlayerNames.$Player "has blackjack!"
                            $BlackjackTable.$Player = $True
                            $MoveFinished.$Player = $True
                            [int]$BlackjackPayout = (($PlayerBetTable.$Player)*1.5)+($PlayerBetTable.$Player)
                            Start-Sleep -Milliseconds $MessageDelay
                            Write-Host
                            Write-Host $PlayerNames.$Player "receives 1.5x their bet for a payout of $BlackjackPayout" -ForegroundColor $MoneyGainColour
                            $PlayerWallets.$Player = ($PlayerWallets.$Player)+$BlackjackPayout
                            $DealerWallet = $DealerWallet-($BlackjackPayout-($PlayerBetTable.$Player))
                            $PlayerBetTable.$Player = 0
                        }
                        # Player does not have blackjack
                        Else {
                            Get-HandValue -CurrentCards $PlayerHand
                            # Player busted
                            If ($Script:PlayerHandValue -gt 21) {
                                $BustedTable.$Player = $True
                                $MoveFinished.$Player = $True
                                Start-Sleep -Milliseconds $MessageDelay
                                Write-Host
                                Write-Host $PlayerNames.$Player "is bust!"
                                Start-Sleep -Milliseconds $MessageDelay
                                Write-Host
                                Write-Host "Dealer collects bet of" $PlayerBetTable.$Player "from" $PlayerNames.$Player -ForegroundColor $MoneyLossColour
                                $DealerWallet = $DealerWallet+($PlayerBetTable.$Player)
                                $PlayerBetTable.$Player = 0
                            }
                            # Player not busted
                            Else {
                                # Determine options
                                If ($PlayerHand.Count -eq 2) {
                                    If (((($CardValues.($PlayerHand[0])) -eq 5) -and (($CardValues.($PlayerHand[1])) -eq 5)) -and ($PlayerWallets.$Player -ge $PlayerBetTable.$Player)) {$PlayerOptions = 'Hit','Stand','Split','Double'}
                                    Elseif (($PlayerHand[0][0] -eq $PlayerHand[1][0]) -and ($PlayerWallets.$Player -ge $PlayerBetTable.$Player)) {$PlayerOptions = 'Hit','Stand','Split'}
                                    Elseif (((9,10,11 -contains $Script:PlayerHandValue) -or (9,10,11 -contains $Script:LowAceValue)) -and ($PlayerWallets.$Player -ge $PlayerBetTable.$Player)) {$PlayerOptions = 'Hit','Stand','Double'}
                                    Else {$PlayerOptions = 'Hit','Stand'}
                                }
                                Elseif (($PlayerHand.Count -gt 2) -and ($Script:PlayerHandValue -eq 21) -and ($Script:LowAceValue -ne 11) -and ($ForceStand)) {$PlayerOptions = 'Stand'}
                                Else {$PlayerOptions = 'Hit','Stand'}
                                Start-Sleep -Milliseconds $MessageDelay
                                If (($PlayerHand.Count -gt 2) -and ($Script:PlayerHandValue -eq 21) -and ($AutoStand)) {$PlayerMovePrompt = 'Stand'}
                                Else {
                                    $PlayerMovePrompt = $Null
                                    Get-PlayerOptions -Choices $PlayerOptions -NameOfPlayer $PlayerNames.$Player -CardsInHand $Script:DisplayHand -ValueOfHand $Script:DisplayHandValue -SplitActive $False
                                }
                                # Prompt for move
                                While ($PlayerOptions -notcontains $PlayerMovePrompt) {
                                    $PlayerMovePrompt = Read-Host $PlayerNames.$Player "what is your move?"
                                    If ('Options','Cards','Bets' -contains $PlayerMovePrompt) {
                                        Switch ($PlayerMovePrompt) {
                                            'Options' {Get-PlayerOptions -Choices $PlayerOptions -NameOfPlayer $PlayerNames.$Player -CardsInHand $Script:DisplayHand -ValueOfHand $Script:DisplayHandValue -SplitActive $False}
                                            'Cards' {Get-PlayerHands}
                                            'Bets' {Get-PlayerBets}
                                        }
                                    }
                                    Elseif ($PlayerOptions -notcontains $PlayerMovePrompt) {
                                        Write-Host
                                        Write-Host "Hint: type 'options' to see available moves" -ForegroundColor $ExInputColour
                                        Write-Host
                                    }
                                }
                                # Do player move
                                Switch ($PlayerMovePrompt) {
                                    'Hit' {
                                        Write-Host
                                        Write-Host $PlayerNames.$Player "hits and is dealt" $Script:Cards[0] -ForegroundColor $ActionColour
                                        [void]$PlayerHand.Add($Script:Cards[0])
                                        Set-Variable $Player -Value $PlayerHand
                                        $Script:Cards.RemoveAt(0)
                                    }
                                    'Stand' {
                                        If (($PlayerHand.Count -gt 2) -and ($Script:PlayerHandValue -eq 21) -and ($AutoStand)) {
                                            Write-Host
                                            Write-Host $PlayerNames.$Player "hand: $Script:DisplayHand" -ForegroundColor $CurrentHandColour
                                            Write-Host $PlayerNames.$Player "hand value: $Script:DisplayHandValue" -ForegroundColor $CurrentHandColour
                                            Start-Sleep -Milliseconds $MessageDelay
                                        }
                                        Write-Host
                                        Write-Host $PlayerNames.$Player "stands on $Script:PlayerHandValue" -ForegroundColor $ActionColour
                                        $MoveFinished.$Player = $True
                                    }
                                    'Double' {
                                        $PlayerDouble.$Player = $True
                                        Write-Host
                                        Write-Host $PlayerNames.$Player "doubles their bet of" $PlayerBetTable.$Player -ForegroundColor $ActionColour
                                        $PlayerWallets.$Player = ($PlayerWallets.$Player)-($PlayerBetTable.$Player)
                                        Start-Sleep -Milliseconds $MessageDelay
                                        Write-Host
                                        Write-Host $PlayerNames.$Player "remaining money:" $PlayerWallets.$Player
                                        Start-Sleep -Milliseconds $MessageDelay
                                        Write-Host
                                        Write-Host $PlayerNames.$Player "draws a card face down and stands" -ForegroundColor $ActionColour
                                        [void]$PlayerHand.Add($Script:Cards[0])
                                        Set-Variable $Player -Value $PlayerHand
                                        $Script:Cards.RemoveAt(0)
                                        $MoveFinished.$Player = $True
                                    }
                                    'Split' {
                                        Write-Host
                                        Write-Host $PlayerNames.$Player "splits cards and matches their bet of" $PlayerBetTable.$Player -ForegroundColor $ActionColour
                                        $PlayerWallets.$Player = ($PlayerWallets.$Player)-($PlayerBetTable.$Player)
                                        Start-Sleep -Milliseconds $MessageDelay
                                        Write-Host
                                        Write-Host $PlayerNames.$Player "remaining money:" $PlayerWallets.$Player
                                        If (($CardValues.($PlayerHand[0])) -eq 11) {
                                            Start-Sleep -Milliseconds $MessageDelay
                                            Write-Host
                                            Write-Host $PlayerNames.$Player "split Aces and may only draw one card per hand"
                                            $SplitAces.$Player = $True
                                        }
                                        $PlayerSplit.$Player = $True
                                        New-Variable SplitList$Player -Value (New-Object System.Collections.ArrayList)
                                        $SplitList = Get-Variable SplitList$Player -ValueOnly
                                        [void]$SplitList.Add("Split1$Player")
                                        [void]$SplitList.Add("Split2$Player")
                                        Set-Variable SplitList$Player -Value $SplitList
                                        New-Variable Split1$Player -Value (New-Object System.Collections.ArrayList)
                                        New-Variable Split2$Player -Value (New-Object System.Collections.ArrayList)
                                        $Split1Hand = Get-Variable Split1$Player -ValueOnly
                                        [void]$Split1Hand.Add($PlayerHand[0])
                                        Start-Sleep -Milliseconds $MessageDelay
                                        Write-Host
                                        Write-Host $PlayerNames.$Player "left hand is dealt" $Script:Cards[0] -ForegroundColor $DealColour
                                        [void]$Split1Hand.Add($Script:Cards[0])
                                        Set-Variable Split1$Player -Value $Split1Hand
                                        $PlayerHand.RemoveAt(0)
                                        $Script:Cards.RemoveAt(0)
                                        $Split2Hand = Get-Variable Split2$Player -ValueOnly
                                        [void]$Split2Hand.Add($PlayerHand[0])
                                        Start-Sleep -Milliseconds $MessageDelay
                                        Write-Host $PlayerNames.$Player "right hand is dealt" $Script:Cards[0] -ForegroundColor $DealColour
                                        [void]$Split2Hand.Add($Script:Cards[0])
                                        Set-Variable Split2$Player -Value $Split2Hand
                                        $PlayerHand.RemoveAt(0)
                                        $Script:Cards.RemoveAt(0)
                                        $SplitRemovalList = @()
                                        $SplitCounter = 0
                                        # Start split turns
                                        Foreach ($Split in $SplitList) {
                                            $SplitCounter = $SplitCounter+1
                                            $SplitTitleLines = ("-")*((($PlayerNames.$Player).Length)+15)
                                            Start-Sleep -Milliseconds $MessageDelay
                                            Write-Host
                                            Write-Host $SplitTitleLines -ForegroundColor $TitleColour
                                            Write-Host $PlayerNames.$Player "- split $SplitCounter turn" -ForegroundColor $TitleColour
                                            Write-Host $SplitTitleLines -ForegroundColor $TitleColour
                                            Start-Sleep -Milliseconds $MessageDelay
                                            $SplitHand = Get-Variable $Split -ValueOnly
                                            $SplitFinished = $False
                                            While ($SplitFinished -ne $True) {
                                                # Split has blackjack
                                                If (($SplitHand.Count -eq 2) -and ((($CardValues.($SplitHand[0]))+($CardValues.($SplitHand[1]))) -eq 21)) {
                                                    $SplitBlackjack.$Split = $True
                                                    Write-Host
                                                    Write-Host $PlayerNames.$Player "split $SplitCounter hand -" $SplitHand[0] $SplitHand[1] -ForegroundColor $CurrentHandColour
                                                    Start-Sleep -Milliseconds $MessageDelay
                                                    Write-Host $PlayerNames.$Player "split $SplitCounter has blackjack!"
                                                    $SplitFinished = $True
                                                    $SplitRemovalList += $Split
                                                    [int]$SplitPayout = ($PlayerBetTable.$Player)*2
                                                    Start-Sleep -Milliseconds $MessageDelay
                                                    Write-Host
                                                    Write-Host $PlayerNames.$Player "receives 1x their split bet for a payout of $SplitPayout" -ForegroundColor $MoneyGainColour
                                                    $PlayerWallets.$Player = ($PlayerWallets.$Player+$SplitPayout)
                                                    $DealerWallet = $DealerWallet-($PlayerBetTable.$Player)
                                                }
                                                # Split doesn't have blackjack
                                                Else {
                                                    Get-HandValue -CurrentCards $SplitHand
                                                    # Split cards were Aces
                                                    If ($SplitAces.$Player -eq $True) {
                                                        Write-Host
                                                        Write-Host $PlayerNames.$Player "split $SplitCounter hand: $Script:DisplayHand" -ForegroundColor $CurrentHandColour
                                                        Write-Host $PlayerNames.$Player "split $SplitCounter hand value: $Script:DisplayHandValue" -ForegroundColor $CurrentHandColour
                                                        Start-Sleep -Milliseconds $MessageDelay
                                                        Write-Host
                                                        Write-Host $PlayerNames.$Player "stands on $Script:PlayerHandValue for split $SplitCounter" -ForegroundColor $ActionColour
                                                        $SplitFinished = $True
                                                    }
                                                    # Split cards were not Aces
                                                    Else {
                                                        # Split busted
                                                        If ($Script:PlayerHandValue -gt 21) {
                                                            $SplitBusted.$Split = $True
                                                            Write-Host
                                                            Write-Host $PlayerNames.$Player "split $SplitCounter is bust!"
                                                            $SplitFinished = $True
                                                            $SplitRemovalList += $Split
                                                            Start-Sleep -Milliseconds $MessageDelay
                                                            Write-Host
                                                            Write-Host "Dealer collects split $SplitCounter bet of" $PlayerBetTable.$Player -ForegroundColor $MoneyLossColour
                                                            $DealerWallet = $DealerWallet+($PlayerBetTable.$Player)
                                                        }
                                                        # Split not busted
                                                        Else {
                                                            # Determine options
                                                            If (($SplitHand.Count -eq 2) -and ((9,10,11 -contains $Script:PlayerHandValue) -or (9,10,11 -contains $Script:LowAceValue)) -and ($PlayerWallets.$Player -ge $PlayerBetTable.$Player)) {$SplitOptions = 'Hit','Stand','Double'}
                                                            Elseif (($SplitHand.Count -gt 2) -and ($Script:PlayerHandValue -eq 21) -and ($Script:LowAceValue -ne 11) -and ($ForceStand)) {$SplitOptions = 'Stand'}
                                                            Else {$SplitOptions = 'Hit','Stand'}
                                                            If (($SplitHand.Count -gt 2) -and ($Script:PlayerHandValue -eq 21) -and ($AutoStand)) {$SplitMovePrompt = 'Stand'}
                                                            Else {
                                                                $SplitMovePrompt = $Null
                                                                Get-PlayerOptions -Choices $SplitOptions -NameOfPlayer $PlayerNames.$Player -CardsInHand $Script:DisplayHand -ValueOfHand $Script:DisplayHandValue -SplitActive $True -SplitNumber $SplitCounter
                                                            }
                                                            # Prompt for split move
                                                            While ($SplitOptions -notcontains $SplitMovePrompt) {
                                                                $SplitMovePrompt = Read-Host $PlayerNames.$Player "what is your move?"
                                                                If ('Options','Cards','Bets' -contains $SplitMovePrompt) {
                                                                    Switch ($SplitMovePrompt) {
                                                                        'Options' {Get-PlayerOptions -Choices $SplitOptions -NameOfPlayer $PlayerNames.$Player -CardsInHand $Script:DisplayHand -ValueOfHand $Script:DisplayHandValue -SplitActive $True -SplitNumber $SplitCounter}
                                                                        'Cards' {Get-PlayerHands}
                                                                        'Bets' {Get-PlayerBets}
                                                                    }
                                                                }
                                                                Elseif ($SplitOptions -notcontains $SplitMovePrompt) {
                                                                    Write-Host
                                                                    Write-Host "Hint: type 'options' to see available moves" -ForegroundColor $ExInputColour
                                                                    Write-Host
                                                                }
                                                            }
                                                            # Do split move
                                                            Switch ($SplitMovePrompt) {
                                                                'Hit' {
                                                                    Write-Host
                                                                    Write-Host $PlayerNames.$Player "hits and is dealt" $Script:Cards[0] -ForegroundColor $ActionColour
                                                                    [void]$SplitHand.Add($Script:Cards[0])
                                                                    Set-Variable $Split -Value $SplitHand
                                                                    $Script:Cards.RemoveAt(0)
                                                                }
                                                                'Stand' {
                                                                    If (($SplitHand.Count -gt 2) -and ($Script:PlayerHandValue -eq 21) -and ($AutoStand)) {
                                                                        Write-Host
                                                                        Write-Host $PlayerNames.$Player "split $SplitCounter hand: $Script:DisplayHand" -ForegroundColor $CurrentHandColour
                                                                        Write-Host $PlayerNames.$Player "split $SplitCounter hand value: $Script:DisplayHandValue" -ForegroundColor $CurrentHandColour
                                                                        Start-Sleep -Milliseconds $MessageDelay
                                                                    }
                                                                    Write-Host
                                                                    Write-Host $PlayerNames.$Player "stands on $Script:PlayerHandValue for split $SplitCounter" -ForegroundColor $ActionColour
                                                                    $SplitFinished = $True
                                                                }
                                                                'Double' {
                                                                    $SplitDouble.$Split = $True
                                                                    Write-Host
                                                                    Write-Host $PlayerNames.$Player "doubles their bet of" $PlayerBetTable.$Player "for split $SplitCounter" -ForegroundColor $ActionColour
                                                                    $PlayerWallets.$Player = ($PlayerWallets.$Player)-($PlayerBetTable.$Player)
                                                                    Start-Sleep -Milliseconds $MessageDelay
                                                                    Write-Host
                                                                    Write-Host $PlayerNames.$Player "remaining money:" $PlayerWallets.$Player
                                                                    Start-Sleep -Milliseconds $MessageDelay
                                                                    Write-Host
                                                                    Write-Host $PlayerNames.$Player "draws a card face down for split $SplitCounter and stands" -ForegroundColor $ActionColour
                                                                    [void]$SplitHand.Add($Script:Cards[0])
                                                                    Set-Variable $Split -Value $SplitHand
                                                                    $Script:Cards.RemoveAt(0)
                                                                    $SplitFinished = $True
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        If ($SplitRemovalList.Count -gt 0) {
                                            Foreach ($Split in $SplitRemovalList) {
                                                $SplitList.Remove($Split)
                                                Set-Variable SplitList$Player -Value $SplitList
                                            }
                                        }
                                        $MoveFinished.$Player = $True
                                    } # End of split
                                }
                            }
                        }
                    } # $MoveFinished loop
                }
            } # Foreach player loop
            # Start settlement
            Get-ActivePlayers
            If (($EndRound -ne $True) -and $Script:HandsInPlay) {
                Write-Host
                Write-Host "----------" -ForegroundColor $TitleColour
                Write-Host "Settlement" -ForegroundColor $TitleColour
                Write-Host "----------" -ForegroundColor $TitleColour
                Foreach ($Player in $Script:PlayerList) {
                    # Player not dealer, bust or blackjack
                    If (($Player -ne "Dealer") -and ($BustedTable.$Player -ne $True) -and ($BlackjackTable.$Player -ne $True)) {
                        $FinalPayout = 0
                        # Dealer bust
                        If ($DealerBusted -eq $True) {
                            If ($PlayerSplit.$Player -eq $True) {
                                $HandList = Get-Variable SplitList$Player -ValueOnly
                                If ($HandList.Count -gt 0) {
                                    Foreach ($Item in $HandList) {
                                        If ($SplitDouble.$Item -eq $True) {$FinalPayout += ($PlayerBetTable.$Player)*4}
                                        Else {$FinalPayout += ($PlayerBetTable.$Player)*2}
                                    }
                                    Start-Sleep -Milliseconds $MessageDelay
                                    Write-Host
                                    Write-Host $PlayerNames.$Player "receives a payout of $FinalPayout" -ForegroundColor $MoneyGainColour
                                    $PlayerWallets.$Player = ($PlayerWallets.$Player)+$FinalPayout
                                    $DealerWallet = $DealerWallet-($FinalPayout/2)
                                }
                            }
                            Else {
                                If ($PlayerDouble.$Player -eq $True) {$FinalPayout = ($PlayerBetTable.$Player)*4}
                                Else {$FinalPayout = ($PlayerBetTable.$Player)*2}
                                Start-Sleep -Milliseconds $MessageDelay
                                Write-Host
                                Write-Host $PlayerNames.$Player "receives a payout of $FinalPayout" -ForegroundColor $MoneyGainColour
                                $PlayerWallets.$Player = ($PlayerWallets.$Player)+$FinalPayout
                                $DealerWallet = $DealerWallet-($FinalPayout/2)
                            }
                        }
                        # Dealer not bust
                        Else {
                            # Player split cards
                            If ($PlayerSplit.$Player -eq $True) {
                                $SplitList = Get-Variable SplitList$Player -ValueOnly
                                Foreach ($Item in $SplitList) {
                                    $SplitHand = Get-Variable $Item -ValueOnly
                                    Get-HandValue -CurrentCards $SplitHand
                                    If ($SplitDouble.$Item -eq $True) {
                                        Start-Sleep -Milliseconds $MessageDelay
                                        Write-Host
                                        Write-Host $PlayerNames.$Player "doubled down on split - checking hand"
                                        Start-Sleep -Milliseconds $MessageDelay
                                        Write-Host $PlayerNames.$Player "third split card is:" $SplitHand[2]
                                    }
                                    Start-Sleep -Milliseconds $MessageDelay
                                    Write-Host
                                    Write-Host $PlayerNames.$Player "split hand:" $Script:DisplayHand -ForegroundColor $CurrentHandColour
                                    Write-Host $PlayerNames.$Player "split hand value:" $Script:PlayerHandValue -ForegroundColor $CurrentHandColour
                                    Write-Host "Dealer hand value:" $Script:DealerStandValue -ForegroundColor $CurrentHandColour
                                    Start-Sleep -Milliseconds $MessageDelay
                                    Write-Host
                                    # Player doubled on split
                                    If ($SplitDouble.$Item -eq $True) {
                                        If ($Script:PlayerHandValue -gt $Script:DealerStandValue) {
                                            $FinalPayout = ($PlayerBetTable.$Player)*4
                                            Write-Host $PlayerNames.$Player "receives a payout of $FinalPayout" -ForegroundColor $MoneyGainColour
                                            $PlayerWallets.$Player = ($PlayerWallets.$Player)+$FinalPayout
                                            $DealerWallet = $DealerWallet-($FinalPayout/2)
                                        }
                                        Elseif ($Script:PlayerHandValue -eq $Script:DealerStandValue) {
                                            $FinalPayout = ($PlayerBetTable.$Player)*2
                                            Write-Host $PlayerNames.$Player "receives back their split bet of $FinalPayout" -ForegroundColor $MoneyEqualColour
                                            $PlayerWallets.$Player = ($PlayerWallets.$Player)+$FinalPayout
                                        }
                                        Elseif ($Script:PlayerHandValue -lt $Script:DealerStandValue) {
                                            $FinalPayout = ($PlayerBetTable.$Player)*2
                                            Write-Host "Dealer collects split bet of $FinalPayout from" $PlayerNames.$Player -ForegroundColor $MoneyLossColour
                                            $DealerWallet = $DealerWallet+$FinalPayout
                                        }
                                    }
                                    # Player did not double on split
                                    Else {
                                        If ($Script:PlayerHandValue -gt $Script:DealerStandValue) {
                                            $FinalPayout = ($PlayerBetTable.$Player)*2
                                            Write-Host $PlayerNames.$Player "receives a payout of $FinalPayout" -ForegroundColor $MoneyGainColour
                                            $PlayerWallets.$Player = ($PlayerWallets.$Player)+$FinalPayout
                                            $DealerWallet = $DealerWallet-($FinalPayout/2)
                                        }
                                        Elseif ($Script:PlayerHandValue -eq $Script:DealerStandValue) {
                                            $FinalPayout = $PlayerBetTable.$Player
                                            Write-Host $PlayerNames.$Player "receives back their split bet of $FinalPayout" -ForegroundColor $MoneyEqualColour
                                            $PlayerWallets.$Player = ($PlayerWallets.$Player)+$FinalPayout
                                        }
                                        Elseif ($Script:PlayerHandValue -lt $Script:DealerStandValue) {
                                            $FinalPayout = $PlayerBetTable.$Player
                                            Write-Host "Dealer collects split bet of $FinalPayout from" $PlayerNames.$Player -ForegroundColor $MoneyLossColour
                                            $DealerWallet = $DealerWallet+$FinalPayout
                                        }
                                    }
                                }
                            }
                            # Player did not split cards
                            Else {
                                $PlayerHand = Get-Variable $Player -ValueOnly
                                Get-HandValue -CurrentCards $PlayerHand
                                If ($PlayerDouble.$Player -eq $True) {
                                    Start-Sleep -Milliseconds $MessageDelay
                                    Write-Host
                                    Write-Host $PlayerNames.$Player "doubled down - checking hand"
                                    Start-Sleep -Milliseconds $MessageDelay
                                    Write-Host $PlayerNames.$Player "third card is:" $PlayerHand[2]
                                }
                                Start-Sleep -Milliseconds $MessageDelay
                                Write-Host
                                Write-Host $PlayerNames.$Player "hand:" $Script:DisplayHand -ForegroundColor $CurrentHandColour
                                Write-Host $PlayerNames.$Player "hand value:" $Script:PlayerHandValue -ForegroundColor $CurrentHandColour
                                Write-Host "Dealer hand value:" $Script:DealerStandValue -ForegroundColor $CurrentHandColour
                                Start-Sleep -Milliseconds $MessageDelay
                                Write-Host
                                # Player doubled
                                If ($PlayerDouble.$Player -eq $True) {
                                    If ($Script:PlayerHandValue -gt $Script:DealerStandValue) {
                                        $FinalPayout = ($PlayerBetTable.$Player)*4
                                        Write-Host $PlayerNames.$Player "receives a payout of $FinalPayout" -ForegroundColor $MoneyGainColour
                                        $PlayerWallets.$Player = ($PlayerWallets.$Player)+$FinalPayout
                                        $DealerWallet = $DealerWallet-($FinalPayout/2)
                                    }
                                    Elseif ($Script:PlayerHandValue -eq $Script:DealerStandValue) {
                                        $FinalPayout = ($PlayerBetTable.$Player)*2
                                        Write-Host $PlayerNames.$Player "receives back their bet of $FinalPayout" -ForegroundColor $MoneyEqualColour
                                        $PlayerWallets.$Player = ($PlayerWallets.$Player)+$FinalPayout
                                    }
                                    Elseif ($Script:PlayerHandValue -lt $Script:DealerStandValue) {
                                        $FinalPayout = ($PlayerBetTable.$Player)*2
                                        Write-Host "Dealer collects bet of $FinalPayout from" $PlayerNames.$Player -ForegroundColor $MoneyLossColour
                                        $DealerWallet = $DealerWallet+$FinalPayout
                                    }
                                }
                                # Player did not double
                                Else {
                                    If ($Script:PlayerHandValue -gt $Script:DealerStandValue) {
                                        $FinalPayout = ($PlayerBetTable.$Player)*2
                                        Write-Host $PlayerNames.$Player "receives a payout of $FinalPayout" -ForegroundColor $MoneyGainColour
                                        $PlayerWallets.$Player = ($PlayerWallets.$Player)+$FinalPayout
                                        $DealerWallet = $DealerWallet-($FinalPayout/2)
                                    }
                                    Elseif ($Script:PlayerHandValue -eq $Script:DealerStandValue) {
                                        $FinalPayout = $PlayerBetTable.$Player
                                        Write-Host $PlayerNames.$Player "receives back their bet of $FinalPayout" -ForegroundColor $MoneyEqualColour
                                        $PlayerWallets.$Player = ($PlayerWallets.$Player)+$FinalPayout
                                    }
                                    Elseif ($Script:PlayerHandValue -lt $Script:DealerStandValue) {
                                        $FinalPayout = $PlayerBetTable.$Player
                                        Write-Host "Dealer collects bet of $FinalPayout from" $PlayerNames.$Player -ForegroundColor $MoneyLossColour
                                        $DealerWallet = $DealerWallet+$FinalPayout
                                    }
                                }
                            }
                        }
                    }
                }
            } # End of settlement
            $EndRound = $True
        } # $EndRound loop
        # Round cleanup
        $PlayerRemovalList = @()
        Foreach ($Player in $Script:PlayerList) {
            # Put dealer cards back into deck
            If ($Player -eq "Dealer") {
                $DealerCount = $Dealer.Count
                For ($CardCount = 1; $CardCount -le $DealerCount; $CardCount++) {
                    [void]$Script:Cards.Add($Dealer[0])
                    $Dealer.RemoveAt(0)
                }
            }
            Else {
                # Put player cards back into deck & remove splits
                If ($PlayerSplit.$Player -eq $True) {
                    $SplitHand1 = Get-Variable Split1$Player -ValueOnly
                    $SplitHand2 = Get-Variable Split2$Player -ValueOnly
                    $SplitCount1 = $SplitHand1.Count
                    $SplitCount2 = $SplitHand2.Count
                    For ($CardCount = 1; $CardCount -le $SplitCount1; $CardCount++) {
                        [void]$Script:Cards.Add($SplitHand1[0])
                        $SplitHand1.RemoveAt(0)
                    }
                    For ($CardCount = 1; $CardCount -le $SplitCount2; $CardCount++) {
                        [void]$Script:Cards.Add($SplitHand2[0])
                        $SplitHand2.RemoveAt(0)
                    }
                    Remove-Variable SplitList$Player
                    Remove-Variable Split1$Player
                    Remove-Variable Split2$Player
                }
                Else {
                    $PlayerCards = Get-Variable $Player -ValueOnly
                    $PlayerCardsCount = $PlayerCards.Count
                    For ($CardCount = 1; $CardCount -le $PlayerCardsCount; $CardCount++) {
                        [void]$Script:Cards.Add($PlayerCards[0])
                        $PlayerCards.RemoveAt(0)
                    }
                    Set-Variable $Player -Value $PlayerCards
                }
                # Remove unsuccessful insurance bets
                If (($InsuranceTrigger.$Player -eq $True) -and ($DealerBlackjack -ne $True)) {
                    $DisplayInsuranceBet = $InsuranceBetTable.$Player
                    Start-Sleep -Milliseconds $MessageDelay
                    Write-Host
                    Write-Host "Dealer collects insurance bet of $DisplayInsuranceBet from" $PlayerNames.$Player -ForegroundColor $MoneyLossColour
                    $DealerWallet = $DealerWallet+($InsuranceBetTable.$Player)
                }
                # Remove bankrupt players from game
                If ($PlayerWallets.$Player -lt $OverallMinimumBet) {
                    Start-Sleep -Milliseconds $MessageDelay
                    Write-Host
                    Write-Host $PlayerNames.$Player "money:" $PlayerWallets.$Player
                    Start-Sleep -Milliseconds $MessageDelay
                    Write-Host $PlayerNames.$Player "cannot afford the minimum bet of `$$OverallMinimumBet"
                    Start-Sleep -Milliseconds $MessageDelay
                    Write-Host
                    Write-Host $PlayerNames.$Player "has been removed from the game" -ForegroundColor $MoneyLossColour
                    $PlayerRemovalList += $Player
                }
            }
        }
        If ($PlayerRemovalList.Count -gt 0) {
            Foreach ($Player in $PlayerRemovalList) {$PlayerList.Remove($Player)}
        }
        $NextRoundPrompt = $Null
        Write-Host
        $RemainingPlayers = $PlayerList.Count
        # End game if all human players bankrupt
        If (($RemainingPlayers -eq 1) -and ($PlayerList.Contains("Dealer"))) {
            $NextRoundPrompt = "N"
            Start-Sleep -Milliseconds $MessageDelay
            Write-Host "There are no human players remaining!" -ForegroundColor $MoneyLossColour
            Start-Sleep -Milliseconds $MessageDelay
        }
        # End game if dealer bankrupt
        Elseif ($DealerWallet -lt (($RemainingPlayers-1)*$OverallMaximumBet)) {
            $NextRoundPrompt = "N"
            Start-Sleep -Milliseconds $MessageDelay
            Write-Host "You have bankrupt the Dealer and been removed from the Casino!" -ForegroundColor $MoneyGainColour
            Start-Sleep -Milliseconds $MessageDelay
        }
        While ("Y","YES","N","NO" -notcontains $NextRoundPrompt) {$NextRoundPrompt = (Read-Host "Do you want to start the next round?(Y/N)").ToUpper()}
        If ("N","NO" -contains $NextRoundPrompt) {$PlayGame = $False}
    } # $PlayGame loop
    $RestartPrompt = $Null
    Write-Host
    While ("Y","YES","N","NO" -notcontains $RestartPrompt) {
        $RestartPrompt = (Read-Host "Do you want to quit?(Y/N)").ToUpper()
        If ("Y","YES" -contains $RestartPrompt) {$QuitValue = $True}
        Elseif ("N","NO" -contains $RestartPrompt) {
            Write-Host
            Write-Host "Restarting game..."
            Foreach ($Player in $Script:PlayerList) {Remove-Variable -Name $Player}
        }
    }
} # $QuitValue loop