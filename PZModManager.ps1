# PZ Mod Manager - Created by duy64. Licensed under the MIT License (see LICENSE.txt).
#Requires -Version 5.1
<#
  PZ Mod Manager v425 - B42 Essentials: mod pack for Single-Player & Multiplayer
  Full collection (~190 mods) + Cheat Menu: Rebuild, no Steam client needed.
#>
$ErrorActionPreference = 'Stop'
$ScriptVersion = '2026-10-12'

$ModsDir     = Join-Path $env:USERPROFILE 'Zomboid\mods'
$ToolsDir    = Join-Path $PSScriptRoot 'tools'
$SteamCmdDir = Join-Path $ToolsDir 'steamcmd'
$SteamCmdExe = Join-Path $SteamCmdDir 'steamcmd.exe'
$AppId       = 108600
$NL          = [Environment]::NewLine

# Target game build. B43 = change these lines; the layout repair and [10] checks derive from them.
$GameBuild = '42'      # major build: version folder name (42/)
$GameBuildFull = '42.21'  # current full build: versionMax floor for [10] warnings
$ScriptVersion = '425'    # app version: shown in the menu header + GUI title

# All known categories, including ones with zero mods right now (Maps /
# Audio / Zombies have no catalog mods yet). The category editor lists
# these so a mod can be assigned to an empty category; Install-AllMods
# uses the same order for its install sequence.
$script:CategoryOrder = @('Frameworks','Vehicles','Aircrafts','Weapons','NPCs','Stories','Events','Map Tools','Movement','Inventory','Medical','Crafting','Quality of Life Mods','Maps & Tiles','Clothing & Gear','Content Mods','Graphics','Cheats','Others')
$GameBuildMinor = ([version]$GameBuildFull).Minor
if ($GameBuildMinor -lt 0) { $GameBuildMinor = 0 }

$script:GuiMode = $false  # $true while the WPF window is open: Pause is a no-op, Beauty grass defaults to Both
$script:WorkshopNameFailed = @{}  # Workshop IDs whose Steam title fetch failed (never re-fetch)

function Get-BuildInfo([string]$text) {
  # Parses "43", "43.1", "43.0.1", "v42.21" -> @{ Build='43'; Full='43.1'; Minor=1 }.
  # Full is normalized to major.minor (the [10] check compares 2-part versionMax).
  # Returns $null when no version number is found.
  $t = $text.Trim() -replace '^[^\d]+', ''
  if ($t -match '^(\d+)(\.(\d+))?') {
    $minor = 0
    if ($Matches[3]) { $minor = [int]$Matches[3] }
    $full = $Matches[1]
    if ($Matches[3]) { $full = $Matches[1] + '.' + $Matches[3] }
    return @{ Build = $Matches[1]; Full = $full; Minor = $minor }
  }
  return $null
}

function Resolve-GameBuild {
  # Default is $GameBuild (42). Confirm it against the game's version.txt:
  # silent when version.txt agrees, prompt when it disagrees or can't be read.
  # The prompt is the safety net for version.txt staleness (it only updates on game launch,
  # lives in the user folder, and reflects whichever install was launched last).
  $defaults = @{ Build = $GameBuild; Full = $GameBuildFull; Minor = $GameBuildMinor }
  $versionFile = Join-Path $env:USERPROFILE 'Zomboid\version.txt'
  $detected = $null
  if (Test-Path $versionFile) {
    $raw = Get-Content $versionFile -Raw -ErrorAction SilentlyContinue
    if ($raw) {
      $first = @($raw -split '\s+' | Where-Object { $_ -ne '' })[0]
      if ($first) { $detected = Get-BuildInfo $first }
    }
  }
  if ($detected -and $detected.Build -eq $GameBuild) { return $defaults }
  if ($detected) {
    Write-Host ("Game version.txt says B" + $detected.Build + " (" + $detected.Full + "), manager default is B" + $GameBuild + ".") -ForegroundColor Yellow
    $answer = Read-Host ("Press Enter to use B" + $detected.Build + " (detected), or type a build")
  } else {
    Write-Host "Could not detect the game version (no readable version.txt)." -ForegroundColor Yellow
    $answer = Read-Host ("Press Enter to use B" + $GameBuild + " (default), or type a build")
  }
  if ([string]::IsNullOrWhiteSpace($answer)) {
    if ($detected) { return $detected }
    return $defaults
  }
  $typed = Get-BuildInfo $answer
  if ($typed) { return $typed }
  Write-Host ("Could not parse '" + $answer + "' - using B" + $GameBuild + " (default).") -ForegroundColor Yellow
  return $defaults
}

# Name / WorkshopId / Cat (Vehicle, Framework, Quality of Life, Content, Cheat)
$Mods = @(
  # ---------- FRAMEWORKS (installed first) ----------
  @{ Name='that DAMN Library (KI5 framework)'; WorkshopId='3171167894'; Cat='Frameworks' },
  @{ Name="Tsar's Common Library B42"; WorkshopId='3402491515'; Cat='Frameworks' },
  @{ Name='NeatUI Framework [B42]'; WorkshopId='3508537032'; Cat='Frameworks' },
  @{ Name='Starlit Library'; WorkshopId='3378285185'; Cat='Frameworks' },
  @{ Name='TchernoLib'; WorkshopId='3389605231'; Cat='Frameworks' },
  @{ Name="Doggy's Library"; WorkshopId='3428272880'; Cat='Frameworks' },
  @{ Name='Broadcast Voicer'; WorkshopId='2973493897'; Cat='Frameworks' },
  @{ Name='ZombieBuddy'; WorkshopId='3619862853'; Cat='Frameworks' },
  @{ Name='Military Tool Kit (tank framework)'; WorkshopId='2705406713'; Cat='Frameworks' },
  @{ Name='[B42] Aviation Core (helicopter framework)'; WorkshopId='3783444342'; Cat='Frameworks' },
  @{ Name='Yet Another PZ Library (YAPZLib)'; WorkshopId='3624971238'; Cat='Frameworks' },
  @{ Name='Moodle Framework (Dynamic Traits dependency)'; WorkshopId='3396446795'; Cat='Frameworks' },

  # ---------- VEHICLES ----------
  @{ Name="'04 Volkswagen Touran"; WorkshopId='3478633453'; Cat='Vehicles' },
  @{ Name="'49 Dodge Power Wagon Crew Cab"; WorkshopId='2900580391'; Cat='Vehicles' },
  @{ Name="'59 Cadillac Miller-Meteor + ECTO-1"; WorkshopId='2772575623'; Cat='Vehicles' },
  @{ Name="'63 Volkswagen 1300 Beetle"; WorkshopId='3005903549'; Cat='Vehicles' },
  @{ Name="'66 Pontiac LeMans / GTO"; WorkshopId='3447272250'; Cat='Vehicles' },
  @{ Name="'67 Cadillac Gage Commando"; WorkshopId='2478247379'; Cat='Vehicles' },
  @{ Name="'67 Shelby GT500 + Eleanor"; WorkshopId='3026723485'; Cat='Vehicles' },
  @{ Name="'68 Pontiac Firebird"; WorkshopId='3258343790'; Cat='Vehicles' },
  @{ Name="'69 Chevrolet Camaro"; WorkshopId='2991201484'; Cat='Vehicles' },
  @{ Name="'69 Mini Mk2"; WorkshopId='2937786633'; Cat='Vehicles' },
  @{ Name="'70 Dodge Challenger"; WorkshopId='2873290424'; Cat='Vehicles' },
  @{ Name="'70 Plymouth Barracuda"; WorkshopId='2913633066'; Cat='Vehicles' },
  @{ Name="'73 Ford Falcon"; WorkshopId='3490370700'; Cat='Vehicles' },
  @{ Name="'75 Pontiac Grand Prix"; WorkshopId='3213391371'; Cat='Vehicles' },
  @{ Name="'76 Chevrolet K Series"; WorkshopId='3161951724'; Cat='Vehicles' },
  @{ Name="'77 Pontiac Firebird"; WorkshopId='3346905070'; Cat='Vehicles' },
  @{ Name="'81 DeLorean DMC-12"; WorkshopId='3253385114'; Cat='Vehicles' },
  @{ Name="'82 Pontiac Firebird"; WorkshopId='3320947974'; Cat='Vehicles' },
  @{ Name="'82 Porsche 911"; WorkshopId='3379334330'; Cat='Vehicles' },
  @{ Name="'84 Jeep XJ Cherokee"; WorkshopId='3409287192'; Cat='Vehicles' },
  @{ Name="'84 Mercedes Benz W460"; WorkshopId='2805630347'; Cat='Vehicles' },
  @{ Name="'85 Buick LeSabre"; WorkshopId='3418252689'; Cat='Vehicles' },
  @{ Name="'85 Chevrolet Caprice / Impala"; WorkshopId='3413704851'; Cat='Vehicles' },
  @{ Name="'85 Oldsmobile Delta 88"; WorkshopId='3418253716'; Cat='Vehicles' },
  @{ Name="'85 Pontiac Parisienne"; WorkshopId='3413706334'; Cat='Vehicles' },
  @{ Name="'86 Chevrolet CUCVs + M101A2 Trailer"; WorkshopId='3428008364'; Cat='Vehicles' },
  @{ Name="'86 Ford Econoline E-150 + Pop Culture vans"; WorkshopId='2870394916'; Cat='Vehicles' },
  @{ Name="'86 Oshkosh P19A + Military Trailers"; WorkshopId='2566953935'; Cat='Vehicles' },
  @{ Name="'87 Buick Regal"; WorkshopId='3226885926'; Cat='Vehicles' },
  @{ Name="'87 Chevrolet Suburban"; WorkshopId='3196180339'; Cat='Vehicles' },
  @{ Name="'87 Ford B700/F700 Trucks"; WorkshopId='3110911330'; Cat='Vehicles' },
  @{ Name="'87 Toyota MR2"; WorkshopId='3052360250'; Cat='Vehicles' },
  @{ Name="'88 Toyota Hilux"; WorkshopId='3435796523'; Cat='Vehicles' },
  @{ Name="'89 Dodge Caravan"; WorkshopId='3034636011'; Cat='Vehicles' },
  @{ Name="'89 Isuzu Trooper"; WorkshopId='2932549988'; Cat='Vehicles' },
  @{ Name="'89 Volvo 200 Series"; WorkshopId='3292659291'; Cat='Vehicles' },
  @{ Name="'90 BMW 3 Series (E30)"; WorkshopId='3110913021'; Cat='Vehicles' },
  @{ Name="'90 Ford F350 Ambulance"; WorkshopId='2952802178'; Cat='Vehicles' },
  @{ Name="'90 Pierce Arrow Pumper and Ladder Trucks"; WorkshopId='2942793445'; Cat='Vehicles' },
  @{ Name="'91 Ford LTD Crown Victoria / Country Squire"; WorkshopId='3366300557'; Cat='Vehicles' },
  @{ Name="'91 Geo Metro"; WorkshopId='3008795514'; Cat='Vehicles' },
  @{ Name="'91 Nissan 240SX"; WorkshopId='3504401781'; Cat='Vehicles' },
  @{ Name="'91 RANGE ROVER Classic"; WorkshopId='2409333430'; Cat='Vehicles' },
  @{ Name="'92 AM General M998 + M101A3 Cargo trailer"; WorkshopId='2642541073'; Cat='Vehicles' },
  @{ Name="'92 Ford Crown Victoria"; WorkshopId='2962175696'; Cat='Vehicles' },
  @{ Name="'92 Jeep YJ Wrangler"; WorkshopId='3287727378'; Cat='Vehicles' },
  @{ Name="'92 NISSAN Skyline GT-R (R32)"; WorkshopId='2846036306'; Cat='Vehicles' },
  @{ Name="'93 Chevrolet Suburban / Silverado"; WorkshopId='3152529790'; Cat='Vehicles' },
  @{ Name="'93 Ford CF8000 Elgin Street Sweeper"; WorkshopId='2969343830'; Cat='Vehicles' },
  @{ Name="'93 Ford F-Series"; WorkshopId='3073430075'; Cat='Vehicles' },
  @{ Name="'93 Ford Mustang"; WorkshopId='3001592312'; Cat='Vehicles' },
  @{ Name="'93 Ford Taurus"; WorkshopId='3088951320'; Cat='Vehicles' },
  @{ Name="'93 Lincoln Town Car + Limo"; WorkshopId='2932547723'; Cat='Vehicles' },
  @{ Name='Autotsar Bus B42'; WorkshopId='3402812859'; Cat='Vehicles' },
  @{ Name='Autotsar Trailers B42'; WorkshopId='3402493701'; Cat='Vehicles' },
  @{ Name='Trailers! (KI5)'; WorkshopId='3330403100'; Cat='Vehicles' },
  @{ Name='Containers! (KI5)'; WorkshopId='2625625421'; Cat='Vehicles' },
  @{ Name='Vanilla vehicles animated'; WorkshopId='3281755175'; Cat='Vehicles' },
  @{ Name='Vehicle Light Chime'; WorkshopId='2742869038'; Cat='Vehicles' },
  @{ Name='Vehicle Military Zones'; WorkshopId='3436499337'; Cat='Vehicles' },
  @{ Name='Vehicle Repair Overhaul'; WorkshopId='2757712197'; Cat='Vehicles' },
  @{ Name='Mileage Expansion'; WorkshopId='2980294462'; Cat='Vehicles' },
  @{ Name="Nepenthe's High Beams"; WorkshopId='3438126404'; Cat='Vehicles' },
  @{ Name='Did I Have A Car?'; WorkshopId='3396100976'; Cat='Vehicles' },
  @{ Name='[B42] Universal Vehicle Key'; WorkshopId='3473160023'; Cat='Vehicles' },
  @{ Name='U.S. M60A3 Tank (Papa_Chad)'; WorkshopId='3739363702'; Cat='Vehicles' },
  @{ Name='R.U. BTR-80 (Papa_Chad)'; WorkshopId='3661387277'; Cat='Vehicles' },
  @{ Name='R.U. BMP-2 (Papa_Chad)'; WorkshopId='3635550823'; Cat='Vehicles' },
  @{ Name='U.S. M113 APC (Papa_Chad)'; WorkshopId='2705655822'; Cat='Vehicles' },
  @{ Name='[B42] M1 Abrams'; WorkshopId='3397147307'; Cat='Vehicles' },
  @{ Name="Maskarad's Summer Car"; WorkshopId='3790160840'; Cat='Vehicles' },
  @{ Name='[B42] UH-1B Helicopter (Beta, flyable)'; WorkshopId='3409723807'; Cat='Aircrafts' },

  # ---------- Quality of Life Mods ----------
  @{ Name='Common Sense [B42.20+]'; WorkshopId='3750253491'; Cat='Quality of Life Mods' },
  @{ Name='Better Sorting'; WorkshopId='2313387159'; Cat='Inventory' },
  @{ Name='Smarter Storage'; WorkshopId='3290232938'; Cat='Inventory' },
  @{ Name='Proximity Inventory'; WorkshopId='2847184718'; Cat='Inventory' },
  @{ Name="Easy Drop'n'Loot"; WorkshopId='2871469707'; Cat='Inventory' },
  @{ Name='CleanUI [B42]'; WorkshopId='3437629766'; Cat='Quality of Life Mods' },
  @{ Name='Rain Cleans Blood [B42]'; WorkshopId='2956146279'; Cat='Quality of Life Mods' },
  @{ Name='[B42] Push Cars by Hand (SP-Only)'; WorkshopId='3393104411'; Cat='Movement' },
  @{ Name='[B42] Hand Bag Window Climb'; WorkshopId='3389093252'; Cat='Movement' },
  @{ Name='[B42] Carry visible generators'; WorkshopId='3390487814'; Cat='Quality of Life Mods' },
  @{ Name='[B41/B42] Load All Magazines'; WorkshopId='2920899878'; Cat='Crafting' },
  @{ Name='Add More Map Symbols (AMMS)'; WorkshopId='3020323164'; Cat='Map Tools' },
  @{ Name='Map Symbol Size Slider'; WorkshopId='2734705913'; Cat='Map Tools' },
  @{ Name='Map Legend UI [B42]'; WorkshopId='2710167561'; Cat='Map Tools' },
  @{ Name='Detailed Map'; WorkshopId='3092033985'; Cat='Map Tools' },
  @{ Name="Erika's tiles [B41/B42]"; WorkshopId='3346506593'; Cat='Maps & Tiles' },
  @{ Name='[B42] Take A Bath And Shower'; WorkshopId='3592172476'; Cat='Content Mods' },
  @{ Name='Functional Appliances 2'; WorkshopId='3042138819'; Cat='Content Mods' },
  @{ Name='Functional Escalators'; WorkshopId='3462962143'; Cat='Content Mods' },
  @{ Name='Fitness & Workout Overhaul'; WorkshopId='2940354599'; Cat='Content Mods' },
  @{ Name='Frozen Days'; WorkshopId='3452955866'; Cat='Content Mods' },
  @{ Name='Oujiangjiang Tiles4 B42'; WorkshopId='3386567345'; Cat='Maps & Tiles' },
  @{ Name='Staff'; WorkshopId='3453333298'; Cat='Content Mods' },
  @{ Name='Taibeiroad4 B42 test'; WorkshopId='3401261192'; Cat='Maps & Tiles' },
  @{ Name='TrapalaketownB42'; WorkshopId='3390327877'; Cat='Maps & Tiles' },
  @{ Name='(STABLE)[B42/B41]Project Seasons'; WorkshopId='3412105017'; Cat='Content Mods' },
  @{ Name='[B42] Arcade Machines'; WorkshopId='3398916952'; Cat='Content Mods' },
  @{ Name='Map Mod Manager'; WorkshopId='3360392628'; Cat='Map Tools' },
  @{ Name='Craft Helper Continued'; WorkshopId='2787291513'; Cat='Crafting' },
  @{ Name='Auto Reload'; WorkshopId='3389448389'; Cat='Crafting' },
  @{ Name='Auto Mechanics'; WorkshopId='3387539308'; Cat='Crafting' },
  @{ Name='Grab and Drop'; WorkshopId='3018929461'; Cat='Movement' },
  @{ Name='Climb'; WorkshopId='3389681224'; Cat='Movement' },
  @{ Name='Climb Down the Rope'; WorkshopId='3000725405'; Cat='Movement' },
  @{ Name='Jump'; WorkshopId='3389606570'; Cat='Movement' },
  @{ Name='Dive Through Windows'; WorkshopId='2891779083'; Cat='Movement' },
  @{ Name='Ladders!?'; WorkshopId='2737665235'; Cat='Movement' },
  @{ Name='Just Throw Them Out The Window'; WorkshopId='2659216714'; Cat='Movement' },
  @{ Name='Read While Walking'; WorkshopId='2845952197'; Cat='Movement' },
  @{ Name='Search Containers'; WorkshopId='2946364542'; Cat='Inventory' },
  @{ Name='Nested Containers'; WorkshopId='2946221823'; Cat='Inventory' },
  @{ Name='Alternative Inventory Rendering'; WorkshopId='2809595776'; Cat='Inventory' },
  @{ Name='Replace Bandage [B41/B42]'; WorkshopId='2944344655'; Cat='Medical' },
  @{ Name='Medicine Moodles'; WorkshopId='3093700684'; Cat='Medical' },
  @{ Name='Medical Meister'; WorkshopId='3173649443'; Cat='Medical' },
  @{ Name='Clear description for Moodles'; WorkshopId='2763647806'; Cat='Medical' },
  @{ Name='Descriptive Tooltips for Skill Levels'; WorkshopId='3134776712'; Cat='Quality of Life Mods' },
  @{ Name='KillCount'; WorkshopId='2553809727'; Cat='Quality of Life Mods' },
  @{ Name='All Shots Fired Increase Aiming XP [B42]'; WorkshopId='3394109542'; Cat='Quality of Life Mods' },
  @{ Name='Take Any Amount'; WorkshopId='2985394645'; Cat='Inventory' },
  @{ Name='Better Hand Wash'; WorkshopId='2594865484'; Cat='Quality of Life Mods' },
  @{ Name='Clean Ashes'; WorkshopId='2816646537'; Cat='Quality of Life Mods' },
  @{ Name="Wesch's Better Wringing 42.20"; WorkshopId='3408740647'; Cat='Quality of Life Mods' },
  @{ Name='Wring Out Clothing'; WorkshopId='2696083206'; Cat='Quality of Life Mods' },
  @{ Name='Working Masks'; WorkshopId='2760742937'; Cat='Quality of Life Mods' },
  @{ Name='Sleep On It'; WorkshopId='2673713236'; Cat='Quality of Life Mods' },
  @{ Name='Warm Up'; WorkshopId='3012122638'; Cat='Quality of Life Mods' },
  @{ Name='Working Treadmill'; WorkshopId='2752895143'; Cat='Quality of Life Mods' },
  @{ Name='Exercise with Gear'; WorkshopId='2513537093'; Cat='Quality of Life Mods' },
  @{ Name='Dig Worms'; WorkshopId='3162507273'; Cat='Quality of Life Mods' },
  @{ Name="Stop, Drop 'n Roll"; WorkshopId='2908614026'; Cat='Quality of Life Mods' },
  @{ Name='Visible Generator Range'; WorkshopId='2972289937'; Cat='Quality of Life Mods' },
  @{ Name='Equip Clothing While Moving [B42]'; WorkshopId='3446510982'; Cat='Movement' },
  @{ Name='Equip Items While Running'; WorkshopId='3492077449'; Cat='Movement' },
  @{ Name='Everything Has a Name'; WorkshopId='2867163008'; Cat='Quality of Life Mods' },
  @{ Name='Material Weight Reducer'; WorkshopId='3387824513'; Cat='Inventory' },
  @{ Name="Skizot's Carryable Everything"; WorkshopId='2921029369'; Cat='Inventory' },
  @{ Name='Responsive Pivoting [B42]'; WorkshopId='2946812728'; Cat='Movement' },
  @{ Name='Reduce lag of Crafting menu'; WorkshopId='2611723883'; Cat='Crafting' },
  @{ Name='On the Door'; WorkshopId='3056481712'; Cat='Quality of Life Mods' },
  @{ Name='zRe Fix Floor'; WorkshopId='3021358003'; Cat='Quality of Life Mods' },
  @{ Name="Cat's eye in the Dark"; WorkshopId='3402513620'; Cat='Quality of Life Mods' },
  @{ Name='ShaderZ'; WorkshopId='3419026942'; Cat='Quality of Life Mods' },
  @{ Name='Better Flashlights'; WorkshopId='2766033079'; Cat='Quality of Life Mods' },
  @{ Name='[B42+] Sandbox Options'; WorkshopId='3386906181'; Cat='Quality of Life Mods' },
  @{ Name='[B42.20] Carry Visible Items In Hands [WIP]'; WorkshopId='3749026793'; Cat='Inventory' },
  @{ Name='Spawn Selector [B42 Stable]'; WorkshopId='3772052709'; Cat='Quality of Life Mods' },
  @{ Name='[B42] Simple Flashlight on Belt!'; WorkshopId='3394588830'; Cat='Quality of Life Mods' },
  @{ Name='[B42.20] Item Arrange'; WorkshopId='3767639280'; Cat='Inventory' },
  @{ Name='PZ Pulse'; WorkshopId='3753700423'; Cat='Quality of Life Mods' },
  @{ Name='PZ Map'; WorkshopId='3770149036'; Cat='Map Tools' },
  @{ Name="Banger's Retro Car Dashboard [B42]"; WorkshopId='3739256322'; Cat='Quality of Life Mods' },
  @{ Name='[B42] Knox Buildworks'; WorkshopId='3772269882'; Cat='Quality of Life Mods' },
  @{ Name='Beyond Ten - Level 15 Skills [B41/B42]'; WorkshopId='3765241705'; Cat='Quality of Life Mods' },
  @{ Name='Practice Crafting Skills'; WorkshopId='3765795716'; Cat='Crafting' },

  # ---------- CONTENT MODS ----------
  @{ Name='Project A-Life [ALIFE NPCS]'; WorkshopId='3803984183'; Cat='NPCs' },
  @{ Name='Project Viewpoint'; WorkshopId='3809306528'; Cat='Graphics' },
  @{ Name='Smokes and Guns'; WorkshopId='3439278895'; Cat='Content Mods' },
  @{ Name='Simple Silencers'; WorkshopId='3309896124'; Cat='Content Mods' },
  @{ Name="Advanced Trajectory's Realistic Overhaul"; WorkshopId='3036878362'; Cat='Content Mods' },
  @{ Name='b42 BonzBetterCombat'; WorkshopId='3391690547'; Cat='Content Mods' },
  @{ Name='Barricade Hurt Zombies'; WorkshopId='2913137598'; Cat='Content Mods' },
  @{ Name='Cheval de frise'; WorkshopId='2927800433'; Cat='Content Mods' },
  @{ Name='Long-standing Metal Constructions'; WorkshopId='3199474685'; Cat='Content Mods' },
  @{ Name='BasedBackpack'; WorkshopId='2992829394'; Cat='Clothing & Gear' },
  @{ Name="Alice's Weapon Sling [B42.20]"; WorkshopId='3775549570'; Cat='Content Mods' },
  @{ Name='Vanilla Clothing Expansion'; WorkshopId='3421271152'; Cat='Clothing & Gear' },
  @{ Name='Vanilla Gear Expanded'; WorkshopId='3401134276'; Cat='Clothing & Gear' },
  @{ Name='[B42] Immersive Camos'; WorkshopId='3454414190'; Cat='Clothing & Gear' },
  @{ Name='Improved Blood Effects'; WorkshopId='2648152698'; Cat='Content Mods' },
  @{ Name='Decoholic'; WorkshopId='3197857648'; Cat='Content Mods' },
  @{ Name='Dynamic Traits and Expanded Moodles'; WorkshopId='2459400130'; Cat='Content Mods' },
  @{ Name="Pillow's Random Spawns [B42]"; WorkshopId='1911132112'; Cat='Content Mods' },
  @{ Name='[B42] Spawn with items by occupation'; WorkshopId='2747517727'; Cat='Content Mods' },
  @{ Name='Horse Mod [B42.20+/MP]'; WorkshopId='3661336777'; Cat='Content Mods' },
  @{ Name='I Am Bruce Lee Now'; WorkshopId='3791279212'; Cat='Content Mods' },
  @{ Name='[B42/MP] Irish''s Dinosaurs'; WorkshopId='3784875732'; Cat='Content Mods' },
  @{ Name='[B42.20] Infirmities'; WorkshopId='3579088411'; Cat='Content Mods' },

  # ---------- WEAPONS (B42 gun packs) ----------
  @{ Name="Totally's Eastern Bloc Firearms [B42.20]"; WorkshopId='2961450523'; Cat='Weapons' },
  @{ Name="Totally's American Firearms [B42.20]"; WorkshopId='3017885370'; Cat='Weapons' },
  @{ Name="Totally's Historical Firearms Pack - Core (TIHFP, may not work on B42)"; WorkshopId='2897536185'; Cat='Weapons' },
  @{ Name='[B42] Post Soviet Armory'; WorkshopId='3722136144'; Cat='Weapons' },
  @{ Name='US Military Grenades [B42]'; WorkshopId='3745718141'; Cat='Weapons' },
  @{ Name='[42.20.4MP] Vanilla Weapons PLUS - Gunworks Edition'; WorkshopId='3773834525'; Cat='Weapons' },

  # ---------- CHEATS ----------
  @{ Name='Cheat Menu: Rebuild'; WorkshopId='3786332527'; Cat='Cheats' },

  # ---------- GRAPHICS ----------
  @{ Name='6244 3D models for Viewpoint'; WorkshopId='3810302175'; Cat='Graphics' },

  # ---------- NPCS (companions & encounters) ----------
  @{ Name='[B42.21] Knox Event Expanded NPC'; WorkshopId='3397396843'; Cat='NPCs' },
  @{ Name='Companion Dogs [ALPHA]'; WorkshopId='3740052292'; Cat='NPCs' },
  @{ Name='CD: Cats'; WorkshopId='3791294616'; Cat='NPCs' },

  # ---------- STORIES / QUESTS ----------
  @{ Name='Zomboid Storylines'; WorkshopId='3620552991'; Cat='Stories' },
  @{ Name='Wolf Extraction Quest'; WorkshopId='2987772693'; Cat='Stories' },
  @{ Name='[B42] Echoes of Knox - Dynamic Story Events'; WorkshopId='3757137484'; Cat='Stories' },

  # ---------- EVENTS ----------
  @{ Name='Dynamic Events [B42.20]'; WorkshopId='3695874178'; Cat='Events' },
  @{ Name='Chaos Mod (450+ random effects)'; WorkshopId='3717082142'; Cat='Events' },
  @{ Name='Extraction Mode'; WorkshopId='3785397275'; Cat='Events' },
  @{ Name='Plane Crash Event (WORKING FOR B42.21) (VIEWPOINT)'; WorkshopId='3773663869'; Cat='Events' },
  @{ Name='Dark Presence'; WorkshopId='3774351457'; Cat='Events' },
  @{ Name='Sun Is Gone [SP/MP]'; WorkshopId='3787603803'; Cat='Events' }
)
$script:DefaultBase = @($Mods)

# User list customization. my-mods.json = mods the user added (the Add-mod catalog). Survives script updates.
$CustomPath = Join-Path $PSScriptRoot 'my-mods.json'
$CustomCategoriesPath = Join-Path $PSScriptRoot 'custom-categories.json'

function Get-CustomCategories {
  # The user's category overrides (custom-categories.json): WorkshopId -> category.
  # Written by the GUI category editor; survives script updates.
  $map = @{}
  if (Test-Path $CustomCategoriesPath) {
    try {
      foreach ($e in @(Get-Content $CustomCategoriesPath -Raw | ConvertFrom-Json)) {
        if ([string]$e.workshopId -ne '' -and [string]$e.cat -ne '') { $cv = [string]$e.cat; if ($cv -eq 'Custom') { $cv = 'Others' }; $map[[string]$e.workshopId] = $cv }
      }
    } catch { }
  }
  return $map
}

function Get-CategoryOverride($workshopId) {
  # One mod's override category, or $null. Lazily loads the map.
  if (-not $script:CustomCategories) { $script:CustomCategories = Get-CustomCategories }
  return $script:CustomCategories[[string]$workshopId]
}

function Save-CustomCategory($workshopId, $cat) {
  # Upsert one override (WorkshopId -> category) into custom-categories.json.
  $list = @()
  if (Test-Path $CustomCategoriesPath) {
    try { $list = @(Get-Content $CustomCategoriesPath -Raw | ConvertFrom-Json) } catch { }
  }
  $found = $false
  foreach ($e in $list) {
    if ([string]$e.workshopId -eq [string]$workshopId) { $e.cat = $cat; $found = $true }
  }
  if (-not $found) {
    $list += [PSCustomObject]@{ workshopId = [string]$workshopId; cat = $cat }
  }
  $list | ConvertTo-Json -Depth 3 | Set-Content $CustomCategoriesPath -Encoding UTF8
  if (-not $script:CustomCategories) { $script:CustomCategories = @{} }
  $script:CustomCategories[[string]$workshopId] = $cat
}


function Apply-CategoryOverrides($mods) {
  # Apply the user's saved category overrides to a mod array in place.
  # Category-based packs (CAT:*) and the install order follow automatically,
  # since they read the same Cat values.
  foreach ($m in @($mods)) {
    $ov = Get-CategoryOverride $m.WorkshopId
    if ($ov) { $m.Cat = $ov }
  }
}

if (Test-Path $CustomPath) {
  try {
    $customList = Get-Content $CustomPath -Raw | ConvertFrom-Json
    foreach ($c in $customList) {
      $Mods += @{ Name = [string]$c.name; WorkshopId = [string]$c.workshopId; Cat = 'Others' }
    }
  } catch { }
}

# Auto-fix: flatten nested collections, drop entries missing id/category
$stack = @($Mods)
$flatMods = @()
while ($stack.Count -gt 0) {
  $m = $stack[0]
  if ($stack.Count -gt 1) { $stack = @($stack[1..($stack.Count-1)]) } else { $stack = @() }
  if ($m -is [System.Collections.IEnumerable] -and $m -isnot [string] -and $m -isnot [System.Collections.IDictionary]) {
    foreach ($sub in $m) { $stack += $sub }
  } else {
    $flatMods += $m
  }
}
$validMods = @()
$badCount = 0
foreach ($m in $flatMods) {
  if ($m -and -not [string]::IsNullOrWhiteSpace([string]$m.WorkshopId) -and [string]$m.Cat -ne '') { $validMods += $m }
  else { $badCount++ }
}
$Mods = $validMods
if ($badCount -gt 0) {
  Write-Host ("WARNING: ignored " + $badCount + " broken mod list entries (missing id/category).") -ForegroundColor Yellow
  Write-Host 'If you see this, please tell me - your my-mods.json may need a cleanup.' -ForegroundColor DarkGray
}

# Category overrides (custom-categories.json, written by the GUI category editor).
# Applied over the catalog + DefaultBase so a script update never wipes the
# user's category choices. The catalog hashtables are shared between $Mods and
# $script:DefaultBase, so one pass covers both; the DefaultBase pass is explicit.
# Pristine built-in categories, captured BEFORE the overrides are baked in.
# Reset Default restores $DefaultBase from this - without it, Reset could
# only clear the override file while $DefaultBase kept the overridden cats,
# so the reset would not restore anything.
$script:BuiltinCats = @{}
foreach ($m in @($script:DefaultBase)) { $script:BuiltinCats[[string]$m.WorkshopId] = [string]$m.Cat }
$script:CustomCategories = Get-CustomCategories
Apply-CategoryOverrides $Mods
Apply-CategoryOverrides $script:DefaultBase


# Named mod lists (lists\*.json). A list is a full profile: mods + packs
# + categories: { name, created, mods: [...], packs: [...], categories: [...] }.
# The active list replaces the working set ($Mods). active.txt holds the
# active list's file-safe name.
$ListsDir = Join-Path $PSScriptRoot 'lists'
$ActiveListFile = Join-Path $ListsDir 'active.txt'
$ModNamesFile = Join-Path $PSScriptRoot 'mod-names.json'

function Get-SafeListName([string]$name) {
  $s = ([string]$name).Trim() -replace '[^A-Za-z0-9 _.-]', '_'
  $s = $s.Trim(' ', '.')
  if ($s -eq '') { $s = 'List' }
  if ($s.Length -gt 60) { $s = $s.Substring(0, 60).Trim() }
  return $s
}

function Get-NamedLists {
  $out = @()
  if (-not (Test-Path $ListsDir)) { return $out }
  foreach ($f in @(Get-ChildItem $ListsDir -Filter '*.json' -File -ErrorAction SilentlyContinue)) {
    try {
      $d = Get-Content $f.FullName -Raw -ErrorAction Stop | ConvertFrom-Json
      $mods = @($d.mods)
      $out += [PSCustomObject]@{ Name = [string]$d.name; Safe = [IO.Path]::GetFileNameWithoutExtension($f.Name); File = $f.FullName; Count = $mods.Count; Created = [string]$d.created }
    } catch { }
  }
  return $out
}

function Get-ActiveListSafe {
  # Active list: active.txt if that list still exists, else the first
  # list, else '' (no lists). 'default' is just a normal list name now
  # (lists/default.json), not a fallback.
  if (Test-Path $ActiveListFile) {
    try {
      $s = (Get-Content $ActiveListFile -Raw -ErrorAction Stop).Trim()
      if ($s -ne '') {
        $exists = @(Get-NamedLists | Where-Object { $_.Safe -eq $s })
        if ($exists.Count -gt 0) { return $s }
      }
    } catch { }
  }
  $all = @(Get-NamedLists)
  if ($all.Count -gt 0) { return [string]$all[0].Safe }
  return ''
}

function Set-ActiveListSafe([string]$safe) {
  New-Item -ItemType Directory -Force -Path $ListsDir | Out-Null
  Set-Content $ActiveListFile ([string]$safe) -Encoding UTF8
}

function Get-NamedListData([string]$safe) {
  $f = Join-Path $ListsDir ([string]$safe + '.json')
  if (-not (Test-Path $f)) { return $null }
  try { return (Get-Content $f -Raw -ErrorAction Stop | ConvertFrom-Json) } catch { return $null }
}

function Save-NamedListData([string]$safe, [string]$name, $mods, $packs = $null, $categories = $null, $tracksCatalog = $null, $removedPacks = $null) {
  # A list is its mods + packs + categories:
  # { name, created, mods: [{workshopId,name,cat}],
  #   packs: [{name,desc,ids,source}], categories: [extra empty names] }.
  # $packs/$categories default to the stored ones (preserved on a
  # mods-only save); pass @() to clear them.
  New-Item -ItemType Directory -Force -Path $ListsDir | Out-Null
  $created = (Get-Date -Format 'yyyy-MM-dd')
  $old = Get-NamedListData $safe
  if ($old -and [string]$old.created -ne '') { $created = [string]$old.created }
  if ($null -eq $packs) { $packs = @($old.packs) }
  if ($null -eq $categories) { $categories = @($old.categories) }
  $packObjs = @($packs | Where-Object { $_ -ne $null -and [string]$_.name -ne '' } | ForEach-Object { [PSCustomObject]@{ name = [string]$_.name; desc = [string]$_.desc; ids = @(@($_.ids) | ForEach-Object { [string]$_ } | Where-Object { $_ -ne '' }); source = [string]$_.source; created = [string]$_.created } })
  $catNames = @($categories | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ -ne '' } | Sort-Object -Unique)
  if ($null -eq $tracksCatalog) {
    # Preserve the flag (a list that tracks the catalog keeps tracking
    # it); a brand-new list defaults to NOT tracking. The seeded
    # Default is created with $true.
    if ($old -and $old.PSObject.Properties['tracksCatalog']) { $tracksCatalog = [bool]$old.tracksCatalog } else { $tracksCatalog = $false }
  }
  if ($null -eq $removedPacks) {
    # Preserve the removed built-in pack names (rename/delete of a
    # built-in pack is per-list); a brand-new list starts empty.
    if ($old -and $old.PSObject.Properties['removedPacks']) { $removedPacks = @($old.removedPacks) } else { $removedPacks = @() }
  }
  $removedNames = @($removedPacks | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ -ne '' } | Sort-Object -Unique)
  $obj = [PSCustomObject]@{ name = [string]$name; created = $created; mods = @($mods | Where-Object { $_ -ne $null -and [string]$_.workshopId -ne '' } | ForEach-Object { [PSCustomObject]@{ workshopId = [string]$_.workshopId; name = [string]$_.name; cat = [string]$_.cat; autoDep = [bool]$_.autoDep } }); packs = $packObjs; categories = $catNames; tracksCatalog = [bool]$tracksCatalog; removedPacks = $removedNames }
  $f = Join-Path $ListsDir ([string]$safe + '.json')
  $obj | ConvertTo-Json -Depth 5 | Set-Content $f -Encoding UTF8
}

function Get-ListDirectMods([string]$safe) {
  # A list's mods: its direct members only, deduped by WorkshopId.
  $d = Get-NamedListData $safe
  if (-not $d) { return @() }
  $out = @()
  $seen = @{}
  foreach ($e in @($d.mods)) {
    $wid = [string]$e.workshopId
    if ([string]::IsNullOrWhiteSpace($wid) -or $seen.ContainsKey($wid)) { continue }
    $seen[$wid] = $true
    $cat = [string]$e.cat
    if ($cat -eq '' -or $cat -eq 'Custom') { $cat = 'Others' }
    $out += [PSCustomObject]@{ workshopId = $wid; name = [string]$e.name; cat = $cat }
  }
  return $out
}

function Get-CustomPacks {
  # Custom packs live in their list's file (packs:[]), not in a global
  # custom-packs.json. This aggregates every list's packs, each tagged
  # with its owning list (List = file-safe list name).
  $out = @()
  if (-not (Test-Path $ListsDir)) { return $out }
  foreach ($f in @(Get-ChildItem $ListsDir -Filter '*.json' -File -ErrorAction SilentlyContinue)) {
    $safe = [IO.Path]::GetFileNameWithoutExtension($f.Name)
    try {
      $d = Get-Content $f.FullName -Raw -ErrorAction Stop | ConvertFrom-Json
      foreach ($cp in @($d.packs)) {
        if ($null -eq $cp -or [string]$cp.name -eq '') { continue }
        $out += @{ Name = [string]$cp.name; Desc = [string]$cp.desc; Ids = @(@($cp.ids) | ForEach-Object { [string]$_ } | Where-Object { $_ -ne '' }); Source = [string]$cp.source; List = $safe; Created = [string]$cp.created }
      }
    } catch { }
  }
  return $out
}

function Get-RemovedPackNames([string]$safe) {
  # Names of built-in packs deleted or renamed away in a list.
  if ([string]$safe -eq '') { return @() }
  $d = Get-NamedListData $safe
  if (-not $d -or -not $d.PSObject.Properties['removedPacks']) { return @() }
  return @(@($d.removedPacks) | ForEach-Object { [string]$_ } | Where-Object { $_ -ne '' })
}

function Set-RemovedPackNames([string]$safe, $names) {
  if ([string]$safe -eq '') { return }
  $d = Get-NamedListData $safe
  if (-not $d) { return }
  Save-NamedListData $safe ([string]$d.name) @($d.mods) @($d.packs) @($d.categories) $null @($names)
}

function Add-RemovedPackName([string]$safe, [string]$packName) {
  $names = @(Get-RemovedPackNames $safe)
  if ($names -notcontains $packName) { $names += $packName; Set-RemovedPackNames $safe $names }
}

function Remove-RemovedPackName([string]$safe, [string]$packName) {
  $names = @(Get-RemovedPackNames $safe)
  if ($names -contains $packName) { Set-RemovedPackNames $safe @($names | Where-Object { $_ -ne $packName }) }
}

function Save-CustomPacks($packs) {
  # Write each pack into its own list's file (packs:[]), grouped by List.
  # Callers pass the full pack array (Get-CustomPacks, modify, save);
  # lists absent from the input get their packs cleared.
  $byList = @{}
  foreach ($p in @($packs)) {
    $lst = [string]$p.List
    if ($lst -eq '') { continue }
    if (-not $byList.ContainsKey($lst)) { $byList[$lst] = @() }
    $byList[$lst] += $p
  }
  foreach ($lst in @($byList.Keys)) {
    $d = Get-NamedListData $lst
    if (-not $d) { continue }
    Save-NamedListData $lst ([string]$d.name) @($d.mods) @($byList[$lst]) $null
  }
  if (Test-Path $ListsDir) {
    foreach ($f in @(Get-ChildItem $ListsDir -Filter '*.json' -File -ErrorAction SilentlyContinue)) {
      $safe = [IO.Path]::GetFileNameWithoutExtension($f.Name)
      if (-not $byList.ContainsKey($safe)) {
        $d = Get-NamedListData $safe
        if ($d -and @($d.packs).Count -gt 0) {
          Save-NamedListData $safe ([string]$d.name) @($d.mods) @() $null
        }
      }
    }
  }
  $script:IdPackIdsCache = $null
}

function Get-AllPacks([switch]$AllLists) {
  # Packs are scoped to a list: built-in packs belong to Default; a
  # custom pack belongs to the list it was created in (its List field).
  # By default this returns only the ACTIVE list's packs, so switching
  # lists shows only that list's packs. -AllLists returns every pack
  # (global lookups). No Hide system: every pack is always visible.
  $out = @()
  $activeList = Get-ActiveListSafe
  $customPacks = @(Get-CustomPacks)
  $customNames = @()
  foreach ($cp0 in $customPacks) {
    if ($AllLists) { $customNames += [string]$cp0.Name }
    elseif ([string]$cp0.List -eq $activeList) { $customNames += [string]$cp0.Name }
  }
  # Built-in packs deleted or renamed away in the active list are
  # hidden there (per-list removedPacks in the list file). Global
  # lookups (-AllLists) ignore the tombstones.
  $removedBuiltins = @()
  if (-not $AllLists -and $activeList -ne '') {
    $ld = Get-NamedListData $activeList
    if ($ld -and $ld.PSObject.Properties['removedPacks']) { $removedBuiltins = @($ld.removedPacks | ForEach-Object { [string]$_ }) }
  }
  foreach ($p in $Packs) {
    # Built-in packs belong to NO list (List = ''): they show in
    # every list. A custom pack in the active list shadows the
    # built-in of the same name (Edit on a built-in converts it to
    # an editable custom pack of the same name).
    if ($customNames -contains [string]$p.Name) { continue }
    if ($removedBuiltins -contains [string]$p.Name) { continue }
    # PSCustomObject, NOT a hashtable: Sort-Object by property name
    # does not resolve hashtable keys in Windows PowerShell 5.1, so
    # the Packs tab Name/Desc sort silently did nothing (same class
    # of bug as v241 for $Mods).
    $out += [PSCustomObject]@{ Name = [string]$p.Name; Desc = [string]$p.Desc; Ids = @($p.Ids); Custom = $false; List = ''; Created = '' }
  }
  foreach ($cp in $customPacks) {
    if (-not $AllLists -and [string]$cp.List -ne $activeList) { continue }
    $out += [PSCustomObject]@{ Name = $cp.Name; Desc = $cp.Desc; Ids = $cp.Ids; Custom = $true; Source = [string]$cp.Source; List = [string]$cp.List; Created = [string]$cp.Created }
  }
  return $out
}

$script:RetiredWorkshopIds = @('3784151798','3780639614','3490188370','3526517370','3504753006','3607686447','3171815531')
function Set-ModsFromNamedList([string]$safe) {
  if (-not (Get-NamedListData $safe)) { return $false }
  $m = @()
  foreach ($e in @(Get-ListDirectMods $safe)) {
    # Skip retired mods (removed from the catalog entirely).
    if ($script:RetiredWorkshopIds -contains [string]$e.workshopId) { continue }
    # PSCustomObject, NOT a hashtable: Sort-Object by property name
    # does not resolve hashtable keys in Windows PowerShell 5.1, so
    # the Mods tab sort silently did nothing (rows stayed in list order).
    # The catalog (BuiltinCats) is the source of truth for catalog mods,
    # so a catalog rearrangement applies to existing lists. The stored
    # Cat is kept only for mods NOT in the catalog. Manual moves live in
    # custom-categories.json and still win via Apply-CategoryOverrides.
    $cat = [string]$e.cat
    if ($script:BuiltinCats -and $script:BuiltinCats.ContainsKey([string]$e.workshopId)) { $cat = [string]$script:BuiltinCats[[string]$e.workshopId] }
    $m += [PSCustomObject]@{ Name = [string]$e.name; WorkshopId = [string]$e.workshopId; Cat = $cat }
  }
  Apply-CategoryOverrides $m
  $script:Mods = $m
  return $true
}

function Get-FullModCatalog {
  # The full mod catalog (DefaultBase + custom additions). Used as the
  # Add-mod catalog: expand packs / look up mods against everything
  # available, not just the current list (a custom list would miss most).
  $m = @($script:DefaultBase)
  if (Test-Path $CustomPath) {
    try {
      foreach ($c in (Get-Content $CustomPath -Raw | ConvertFrom-Json)) {
        $m += @{ Name = [string]$c.name; WorkshopId = [string]$c.workshopId; Cat = 'Others' }
      }
    } catch { }
  }
  Apply-CategoryOverrides $m
  return $m
}

function Get-WorkshopNames {
  if ($script:WorkshopNames -eq $null) {
    $script:WorkshopNames = @{}
    if (Test-Path $ModNamesFile) {
      try {
        $d = Get-Content $ModNamesFile -Raw -ErrorAction Stop | ConvertFrom-Json
        foreach ($p in $d.PSObject.Properties) { $script:WorkshopNames[[string]$p.Name] = [string]$p.Value }
      } catch { }
    }
  }
  return $script:WorkshopNames
}

function Save-WorkshopNames {
  try {
    $names = Get-WorkshopNames
    $obj = New-Object PSObject
    foreach ($k in @($names.Keys | Sort-Object)) { if (-not [string]::IsNullOrWhiteSpace([string]$k)) { $obj | Add-Member -NotePropertyName $k -NotePropertyValue $names[$k] } }
    ($obj | ConvertTo-Json -Depth 2) | Set-Content $ModNamesFile -Encoding UTF8 -Force
  } catch { }
}

# Steam requires TLS 1.2+; PS 5.1 defaults to older protocols.
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }
function Get-WorkshopModCategories($ids) {
  # Batched Steam lookup: WorkshopId -> Steam-tag category
  # (Get-SteamTagCategory on the item's tags). One API call per 100
  # IDs. Returns @{} on failure (caller falls back to 'Others').
  # Never throws.
  $out = @{}
  $need = @($ids | Where-Object { [string]$_ -ne '' } | Sort-Object -Unique)
  for ($b = 0; $b -lt $need.Count; $b += 100) {
    $end = [Math]::Min($b + 99, $need.Count - 1)
    $batch = @($need[$b..$end])
    $body = 'itemcount=' + $batch.Count
    for ($k = 0; $k -lt $batch.Count; $k++) { $body += '&publishedfileids[' + $k + ']=' + $batch[$k] }
    try {
      $r = Invoke-WebRequest -Uri 'https://api.steampowered.com/ISteamRemoteStorage/GetPublishedFileDetails/v1/' -Method Post -Body $body -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
      $d = $r.Content | ConvertFrom-Json
      foreach ($item in @($d.response.publishedfiledetails)) {
        if ([int]$item.result -eq 1 -and [int]$item.consumer_app_id -eq 108600) {
          $tags = @($item.tags | ForEach-Object { [string]$_.tag })
          $out[[string]$item.publishedfileid] = (Get-SteamTagCategory $tags)
        }
      }
    } catch { }
  }
  return $out
}

function Resolve-EntryCategories($entries) {
  # Fill in Cat for entries that lack one (Workshop Search / Browse
  # Popular return Name + ID only): catalog Cat first, then one
  # batched Steam-tag lookup, else Others. Entries with a Cat are
  # untouched. Returns the entries with Cat set. Never throws.
  try {
    $catalog = @(Get-FullModCatalog)
    $needSteam = @()
    foreach ($e in @($entries)) {
      if ([string]$e.Cat -ne '') { continue }
      $cat = ''
      foreach ($m in $catalog) { if ([string]$m.WorkshopId -eq [string]$e.WorkshopId) { $cat = [string]$m.Cat; break } }
      if ($cat -ne '') { $e.Cat = $cat } else { $needSteam += [string]$e.WorkshopId }
    }
    if ($needSteam.Count -gt 0) {
      $steamCats = Get-WorkshopModCategories $needSteam
      foreach ($e in @($entries)) {
        if ([string]$e.Cat -ne '') { continue }
        if ($steamCats.ContainsKey([string]$e.WorkshopId)) { $e.Cat = $steamCats[[string]$e.WorkshopId] } else { $e.Cat = 'Others' }
      }
    }
  } catch { }
  return $entries
}

function Get-SteamTagCategory($tags) {
  # Map Steam Workshop tags to a manager category (first matching tag wins).
  # Steam has no category field — tags are freeform creator-chosen labels,
  # so this is best-effort: a mod tagged only 'Build 42' (or untagged)
  # still lands in 'Others'. Words are matched whole (singular/plural), not
  # substrings, so 'Build' doesn't false-match 'ui'.
  $phrases = @{ 'quality of life' = 'Quality of Life Mods'; 'co-op' = 'Multiplayer Mods' }
  $words = @{ vehicle = 'Vehicles'; car = 'Vehicles'; truck = 'Vehicles'; weapon = 'Weapons'; gun = 'Weapons'; firearm = 'Weapons'; aircraft = 'Aircrafts'; helicopter = 'Aircrafts'; plane = 'Aircrafts'; npc = 'NPCs'; survivor = 'NPCs'; story = 'Stories'; quest = 'Stories'; lore = 'Stories'; event = 'Events'; multiplayer = 'Multiplayer Mods'; coop = 'Multiplayer Mods'; qol = 'Quality of Life Mods'; ui = 'Quality of Life Mods'; interface = 'Quality of Life Mods'; cheat = 'Cheats'; admin = 'Cheats'; graphics = 'Graphics'; visual = 'Graphics'; texture = 'Graphics'; model = 'Graphics'; framework = 'Frameworks'; library = 'Frameworks'; api = 'Frameworks'; ship = 'Ships'; boat = 'Ships'; content = 'Content Mods'; clothing = 'Content Mods'; item = 'Content Mods'; furniture = 'Content Mods' }
  foreach ($t in @($tags)) {
    $tl = ([string]$t).Trim().ToLower()
    if ($phrases.ContainsKey($tl)) { return $phrases[$tl] }
    foreach ($w in @($tl -split '[^a-z0-9]+' | Where-Object { $_ -ne '' })) {
      if ($words.ContainsKey($w)) { return $words[$w] }
      if ($w.Length -gt 1 -and $w.EndsWith('s') -and $words.ContainsKey($w.Substring(0, $w.Length - 1))) { return $words[$w.Substring(0, $w.Length - 1)] }
    }
  }
  return 'Others'
}

function Get-WorkshopModDetails([string]$id) {
  # Title + Steam-tag-derived category for a Workshop ID not in the catalog.
  # One API call; the title is cached in mod-names.json (so later name-only
  # lookups don't re-fetch). Always returns @{ Name; Category; Status }:
  # Valid = a real Project Zomboid Workshop item (consumer_app_id 108600);
  # NotFound = Steam has no such item (result 9); WrongGame = the item is
  # for a different game (e.g. Cities: Skylines); Unknown = the API could
  # not be reached (offline) - the caller decides whether to allow it.
  $id = [string]$id
  if ($id -eq '') { return @{ Name = ''; Category = 'Others'; Status = 'Unknown' } }
  try {
    $r = Invoke-WebRequest -Uri 'https://api.steampowered.com/ISteamRemoteStorage/GetPublishedFileDetails/v1/' -Method Post -Body ('itemcount=1&publishedfileids[0]=' + $id) -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    $d = $r.Content | ConvertFrom-Json
    $detail = @($d.response.publishedfiledetails)[0]
    if ($detail -and [int]$detail.result -eq 1) {
      if ([int]$detail.consumer_app_id -ne 108600) { return @{ Name = ''; Category = 'Others'; Status = 'WrongGame' } }
      if ([string]$detail.title -ne '') {
        $names = Get-WorkshopNames
        $names[$id] = [string]$detail.title
        Save-WorkshopNames
        $tags = @($detail.tags | ForEach-Object { [string]$_.tag })
        return @{ Name = [string]$detail.title; Category = (Get-SteamTagCategory $tags); Status = 'Valid' }
      }
    }
    return @{ Name = ''; Category = 'Others'; Status = 'NotFound' }
  } catch { }
  return @{ Name = ''; Category = 'Others'; Status = 'Unknown' }
}

function Get-WorkshopModName([string]$id) {
  # Title for a Workshop ID not in the catalog (cached; $null on failure).
  $id = [string]$id
  if ($id -eq '') { return $null }
  $names = Get-WorkshopNames
  if ($names.ContainsKey($id)) { return $names[$id] }
  $detail = Get-WorkshopModDetails $id
  if ($detail -and $detail.Status -eq 'Valid') { return $detail.Name }
  return $null
}

function Parse-ModIdsFromText([string]$text) {
  $out = @()
  $seen = @{}
  $tokens = @([string]$text -split '[,;\s]+' | Where-Object { $_ -ne '' })
  foreach ($tok in $tokens) {
    $id = Get-WorkshopIdFromInput $tok
    if (-not $id) { continue }
    if ($seen.ContainsKey($id)) { continue }
    $seen[$id] = $true
    $nm = $id; $cat = 'Others'
    foreach ($m in $script:Mods) { if ([string]$m.WorkshopId -eq $id) { $nm = [string]$m.Name; $cat = [string]$m.Cat; break } }
    if ($nm -eq $id) {
      # Not in the working set: try the full catalog (the active list may
      # not include it), then ask Steam for the title (cached in
      # mod-names.json). Falls back to the ID if Steam can't answer.
      foreach ($m in (Get-FullModCatalog)) { if ([string]$m.WorkshopId -eq $id) { $nm = [string]$m.Name; $cat = [string]$m.Cat; break } }
    }
    # Validation: catalog IDs are known-good. Non-catalog IDs are
    # checked against Steam - NotFound / WrongGame are rejected
    # by the Add handlers (Valid = $false). Unknown (offline) is
    # allowed through (Name stays the ID) so an offline add still
    # works; it will resolve to the real name on a later refresh.
    $valid = $true; $reject = ''
    if ($nm -eq $id) {
      $detail = Get-WorkshopModDetails $id
      if ($detail.Status -eq 'Valid') { $nm = $detail.Name; $cat = $detail.Category }
      elseif ($detail.Status -eq 'NotFound') { $valid = $false; $reject = 'not found on Workshop' }
      elseif ($detail.Status -eq 'WrongGame') { $valid = $false; $reject = 'not a Project Zomboid mod' }
    }
    $out += [PSCustomObject]@{ WorkshopId = [string]$id; Name = [string]$nm; Cat = [string]$cat; Valid = [bool]$valid; RejectReason = [string]$reject }
  }
  return $out
}


function Add-EntriesToActiveList($entries) {
  # Every list (including Default) saves to its list file.
  $entries = Resolve-EntryCategories $entries
  $active = Get-ActiveListSafe
  $d = Get-NamedListData $active
  if (-not $d) { return }
  $mods = @($d.mods)
  $have = @{}
  foreach ($mm in $mods) { $have[[string]$mm.workshopId] = $true }
  foreach ($e in $entries) {
    if (-not $have.ContainsKey([string]$e.WorkshopId)) {
      $mods += [PSCustomObject]@{ workshopId = [string]$e.WorkshopId; name = [string]$e.Name; cat = [string]$e.Cat }
      $have[[string]$e.WorkshopId] = $true
    }
  }
  Save-NamedListData $active $d.name $mods
  Set-ModsFromNamedList $active | Out-Null
}


# Themed packs: pick a bundle instead of everything.
# Ids can hold Workshop IDs, or 'CAT:<category>' to include every mod in that
# category - so a new mod in a category auto-joins its pack (no pack edit needed).
# Packs that stay ID-based are deliberately selective (see notes below).
$Packs = @(
  @{ Name='Aircrafts Pack'; Desc='Flyable UH-1B Huey helicopter + Aviation Core framework (both beta)'; Ids=@('3783444342','3409723807') },
  @{ Name='Tanks Pack'; Desc='M60A3, BTR-80, BMP-2, M113 APC, M1 Abrams + Military Tool Kit (driveable, working turrets)'; Ids=@('2705406713','3739363702','3661387277','3635550823','2705655822','3397147307') },
  # Guns Pack is hand-picked: it excludes TIHFP Historical (may not work on B42).
  @{ Name='Guns Pack'; Desc='B42 gun packs: Totally East Bloc + American, Post Soviet Armory, US Grenades'; Ids=@('2961450523','3017885370','3722136144','3745718141') },
  # KI5 Fleet is hand-picked: when a KI5 car is added to $Mods, add its ID here too.
  @{ Name='KI5 Vehicles Pack'; Desc='Every KI5 car in the pack (50+ vehicles, big download)'; Ids=@('3478633453','2900580391','2772575623','3005903549','3447272250','2478247379','3026723485','3258343790','2991201484','2937786633','2873290424','2913633066','3490370700','3213391371','3161951724','3346905070','3253385114','3320947974','3379334330','3409287192','2805630347','3418252689','3413704851','3418253716','3413706334','3428008364','2870394916','2566953935','3226885926','3196180339','3110911330','3052360250','3435796523','3034636011','2932549988','3292659291','3110913021','2952802178','2942793445','3366300557','3008795514','3504401781','2409333430','2642541073','2962175696','3287727378','2846036306','3152529790','2969343830','3073430075','3001592312','3088951320','2932547723') },
  @{ Name='Quality of Life Essentials Pack'; Desc='All quality-of-life mods (Common Sense, sorting, loot helpers, map tools...)'; Ids=@('CAT:Quality of Life Mods') },
  # NOTE: Mod Update and Alert System (3077900375) + Skill Recovery Journal (2503622437) + Conditional Speech (2398253681) + errorMagnifier (2896041179) removed 2026-10-13 - Alert System makes the in-game UI disappear on B42.21; Skill Recovery require=s it so it cannot load without it.
# NOTE: Voiced Radio and TVs (2950750587) removed 2026-10-13 - requires VOICE_FRAMEWORK, no Workshop item exists for it (searched Steam API, author page, site-search), so it cannot run.
# NOTE: Authentic Z (2335368829) + True Music Radio 42 (3631572046) removed 2026-10-13 - SteamCMD consistently returns 'ERROR! Download item failed (Failure)' for them. Workshop pages are still live/B42-compatible, so they can be re-added via [4] Install by URL if Steam fixes it.
  # Living Worlds Pack is Viewpoint only: A-Life lives in NPCs Pack (via CAT:NPCs) and ZombieBuddy is a Viewpoint dependency (DepMap) so it auto-installs — listing either here would overlap NPCs Pack.
  @{ Name='Living Worlds Pack'; Desc='Project Viewpoint (first-person; ZombieBuddy auto-installed as a dependency)'; Ids=@('3809306528') },
  @{ Name='Cheats Pack'; Desc='Cheat Menu: Rebuild'; Ids=@('CAT:Cheats') },
  # Graphics Pack is hand-picked: models only - Viewpoint itself is in Living Worlds Pack.
  @{ Name='Graphics Pack'; Desc='6244 3D models for Viewpoint (first-person)'; Ids=@('3810302175') },
  @{ Name='NPCs Pack'; Desc='All NPC mods: A-Life NPCs, Knox Event Expanded NPC, Companion Dogs (+ ZombieBuddy)'; Ids=@('CAT:NPCs','3619862853') },
  @{ Name='Stories Pack'; Desc='Zomboid Storylines, Wolf Extraction Quest, Echoes of Knox'; Ids=@('CAT:Stories') },
  @{ Name='Events Pack'; Desc='Dynamic Events [B42.20], Chaos Mod'; Ids=@('CAT:Events') },
  @{ Name='Multiplayer Mods Pack'; Desc='B42 MP essentials: leaderboards, push vehicle, cooking UI, minimap, horde pressure, blackouts, safehouse'; Ids=@('CAT:Multiplayer Mods') },
  @{ Name='Vehicles Pack'; Desc='All vehicle mods (KI5 cars and Tanks also have their own curated packs)'; Ids=@('CAT:Vehicles') },
  @{ Name='Weapons Pack'; Desc='All weapon mods (Guns Pack is the curated B42-tested subset)'; Ids=@('CAT:Weapons') },
  @{ Name='Content Mods Pack'; Desc='All content mods (furniture, clothing, gameplay additions, misc)'; Ids=@('CAT:Content Mods') },
  @{ Name='Frameworks Pack'; Desc='All framework and library mods (dependencies other mods need)'; Ids=@('CAT:Frameworks') }
  @{ Name='Map Tools Pack'; Desc='All map mods (map symbols, legend, detailed map, live map)'; Ids=@('CAT:Map Tools') },
  @{ Name='Movement Pack'; Desc='All movement mods (climb, jump, ladders, window traversal, equip while moving)'; Ids=@('CAT:Movement') },
  @{ Name='Inventory Pack'; Desc='All inventory mods (sorting, storage, containers, carry weight)'; Ids=@('CAT:Inventory') },
  @{ Name='Medical Pack'; Desc='All medical mods (bandages, moodles, medical UI)'; Ids=@('CAT:Medical') },
  @{ Name='Crafting Pack'; Desc='All crafting mods (craft helper, auto reload, auto mechanics, practice)'; Ids=@('CAT:Crafting') },
  @{ Name='Maps & Tiles Pack'; Desc='All map-content mods (tiles, map expansions)'; Ids=@('CAT:Maps & Tiles') },
  @{ Name='Clothing & Gear Pack'; Desc='All clothing and gear mods (clothing expansion, backpacks, camos)'; Ids=@('CAT:Clothing & Gear') }
)

function Migrate-ListStorage {
  # v206 one-time migration. Packs + empty-category names move into their
  # list files; Default becomes a real list file (lists/default.json).
  # Runs once (marker lists/.initialized); later runs are no-ops.
  # hidden-packs.json / removed-mods.json are no longer read (Hide is
  # gone): hidden mods return to the catalog, hidden packs return to
  # view. Those files are left in place as a backup, never deleted.
  New-Item -ItemType Directory -Force -Path $ListsDir | Out-Null
  $marker = Join-Path $ListsDir '.initialized'
  if (Test-Path $marker) { return }
  # Seed Default as a real list file from the current working set
  # (DefaultBase + the user's added mods, so nothing is lost).
  # A v205 user-created list named 'Default' (lists/default.json) would
  # shadow the real Default with its own mods: back it up and seed the
  # real Default. On first migration a default.json can only be a
  # v205 conflict - the real Default was never a file before v206.
  if (Test-Path (Join-Path $ListsDir 'default.json')) {
    $bk = Join-Path $ListsDir 'default-v205-backup.json'
    $bi = 1
    while (Test-Path $bk) { $bi++; $bk = Join-Path $ListsDir ('default-v205-backup-{0}.json' -f $bi) }
    Move-Item -Path (Join-Path $ListsDir 'default.json') -Destination $bk -Force -ErrorAction SilentlyContinue
  }
  $mods = @($Mods | ForEach-Object { [PSCustomObject]@{ workshopId = [string]$_.WorkshopId; name = [string]$_.Name; cat = [string]$_.Cat } })
  Save-NamedListData 'default' 'Default' $mods @() @() $true
  # Move custom-packs.json packs into their list files.
  $oldPacks = Join-Path $PSScriptRoot 'custom-packs.json'
  if (Test-Path $oldPacks) {
    try {
      $d = Get-Content $oldPacks -Raw -ErrorAction Stop | ConvertFrom-Json
      foreach ($cp in @($d)) {
        $lst = [string]$cp.list
        if ($lst -eq '') { $lst = 'default' }
        $ld = Get-NamedListData $lst
        if (-not $ld) { continue }
        $packs = @(@($ld.packs) | Where-Object { $_ -ne $null -and [string]$_.name -ne '' })
        $packs += [PSCustomObject]@{ name = [string]$cp.name; desc = [string]$cp.desc; ids = @($cp.ids | ForEach-Object { [string]$_ }); source = [string]$cp.source }
        Save-NamedListData $lst ([string]$ld.name) @($ld.mods) $packs $null
      }
    } catch { }
    Move-Item $oldPacks ($oldPacks + '.migrated') -Force -ErrorAction SilentlyContinue
  }
  # Move custom-category-names.json into Default's categories.
  $oldCats = Join-Path $PSScriptRoot 'custom-category-names.json'
  if (Test-Path $oldCats) {
    try {
      $names = @(Get-Content $oldCats -Raw -ErrorAction Stop | ConvertFrom-Json | ForEach-Object { [string]$_ })
      $ld = Get-NamedListData 'default'
      if ($ld -and $names.Count -gt 0) {
        $cats = @(@($ld.categories) | ForEach-Object { [string]$_ })
        foreach ($n in $names) { if ($cats -notcontains $n) { $cats += $n } }
        Save-NamedListData 'default' ([string]$ld.name) @($ld.mods) $null $cats
      }
    } catch { }
    Move-Item $oldCats ($oldCats + '.migrated') -Force -ErrorAction SilentlyContinue
  }
  Set-Content $marker 'v206' -Encoding UTF8
}

# Startup: migrate list storage to v206 (packs + empty-category names
# move into their list files; Default becomes a real list file), then
# load the active list's mods into the working set.
Migrate-ListStorage
# Restore Default if there is no list to load (every list deleted):
# the app never starts with an empty list set. An emptied Default
# is NOT restored - only a missing Default (zero lists) is.
if (@(Get-NamedLists).Count -eq 0) {
  $mods = @($Mods | ForEach-Object { [PSCustomObject]@{ workshopId = [string]$_.WorkshopId; name = [string]$_.Name; cat = [string]$_.Cat } })
  Save-NamedListData 'default' 'Default' $mods @() @() $true
  Set-ActiveListSafe 'default'
}
# Sync Default with the catalog: Default is the catalog list, so when
# the catalog grows (new mods added), Default gains the missing catalog
# mods. Existing entries (including the user's own additions and
# autoDep flags) are kept; nothing is removed. Custom lists are NOT
# synced - only Default tracks the catalog. Packs/categories preserved
# (Save-NamedListData keeps the stored ones when passed $null).
$__def = Get-NamedListData 'default'
if ($__def) {
  $__tracks = $false
  if ($__def.PSObject.Properties['tracksCatalog']) { $__tracks = [bool]$__def.tracksCatalog }
  else {
    # Pre-v377 Default has no flag: it is the seeded catalog list.
    # Grant the flag once (a user-created list named Default made
    # AFTER v377 carries tracksCatalog=$false and is never synced).
    $__tracks = $true
    Save-NamedListData 'default' ([string]$__def.name) $__def.mods $null $null $true
    $__def = Get-NamedListData 'default'
  }
}
if ($__def -and $__tracks) {
  $__have = @{}
  foreach ($__e in @($__def.mods)) { $__have[[string]$__e.workshopId] = $true }
  $__missing = @()
  foreach ($__cm in @($Mods)) {
    if (-not $__have.ContainsKey([string]$__cm.WorkshopId)) {
      $__missing += [PSCustomObject]@{ workshopId = [string]$__cm.WorkshopId; name = [string]$__cm.Name; cat = [string]$__cm.Cat; autoDep = $false }
    }
  }
  if ($__missing.Count -gt 0) {
    $__merged = @($__def.mods | ForEach-Object { [PSCustomObject]@{ workshopId = [string]$_.workshopId; name = [string]$_.name; cat = [string]$_.cat; autoDep = [bool]$_.autoDep } }) + $__missing
    Save-NamedListData 'default' ([string]$__def.name) $__merged $null $null
  }
}
# Default is a plain list. An emptied Default stays empty.
$__activeSafe = Get-ActiveListSafe
if ($__activeSafe -ne '') {
  if (-not (Set-ModsFromNamedList $__activeSafe)) { Set-ActiveListSafe ''; $script:Mods = @() }
} else { $script:Mods = @() }

function Ensure-SteamCmd {
  if (Test-Path $SteamCmdExe) { return }
  Write-Host 'Downloading SteamCMD (~10 MB)...' -ForegroundColor Yellow
  New-Item -ItemType Directory -Force -Path $SteamCmdDir | Out-Null
  $zip = Join-Path $ToolsDir 'steamcmd.zip'
  Invoke-WebRequest -Uri 'https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip' -OutFile $zip
  Expand-Archive -Path $zip -DestinationPath $SteamCmdDir -Force
  Remove-Item $zip -Force
  Write-Host 'SteamCMD ready.' -ForegroundColor Green
}

function Get-WorkshopIdFromInput([string]$s) {
  if ($s -match '(\d{6,})') { return $Matches[1] }
  return $null
}

$MapPath = Join-Path $ToolsDir 'install-map.json'

function Get-InstallMap {
  if (Test-Path $MapPath) {
    try { return (Get-Content $MapPath -Raw | ConvertFrom-Json) } catch { }
  }
  return $null
}

function Save-InstallMap($map) {
  $map | ConvertTo-Json -Depth 5 | Set-Content $MapPath -Encoding UTF8
}

function Get-ModDiskSize($folderNames) {
  # Total bytes of a mod's installed folders (0 when none/missing).
  $total = [long]0
  foreach ($fn in @($folderNames)) {
    $dir = Join-Path $ModsDir ([string]$fn)
    if (-not (Test-Path $dir)) { continue }
    $sum = (Get-ChildItem $dir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    if ($sum) { $total += [long]$sum }
  }
  return $total
}

function Format-ModSize([long]$bytes) {
  # Human-readable size for the Mods tab Size column (blank for 0).
  if ($bytes -le 0) { return '' }
  if ($bytes -ge 1073741824) { return ('{0:N2} GB' -f ($bytes / 1073741824.0)) }
  if ($bytes -ge 1048576) { return ('{0:N1} MB' -f ($bytes / 1048576.0)) }
  if ($bytes -ge 1024) { return ('{0:N0} KB' -f ($bytes / 1024.0)) }
  return ([string]$bytes + ' B')
}

function Get-ContentStamp($path) {
  # Content-based stamp (NOT mtime): SteamCMD re-downloads change file
  # mtimes even when content is identical, which made every check report
  # phantom "updates" for freshly installed mods. This hashes relative
  # paths + file sizes + content, so identical downloads give identical
  # stamps regardless of when they were downloaded.
  try { Add-Type -AssemblyName System.Security -ErrorAction SilentlyContinue } catch { }
  $sha = [System.Security.Cryptography.SHA256]::Create()
  $files = @(Get-ChildItem $path -Recurse -File -ErrorAction SilentlyContinue | Sort-Object FullName)
  foreach ($f in $files) {
    $rel = $f.FullName.Substring($path.Length)
    $meta = [System.Text.Encoding]::UTF8.GetBytes($rel + '|' + $f.Length + '|')
    [void]$sha.TransformBlock($meta, 0, $meta.Length, $null, 0)
    try {
      $stream = $f.OpenRead()
      try {
        $buf = New-Object byte[] 8192
        while (($read = $stream.Read($buf, 0, $buf.Length)) -gt 0) {
          [void]$sha.TransformBlock($buf, 0, $read, $null, 0)
        }
      } finally { $stream.Close() }
    } catch { }
  }
  [void]$sha.TransformFinalBlock([byte[]]@(), 0, 0)
  $hash = [BitConverter]::ToString($sha.Hash).Replace('-', '')
  $sha.Dispose()
  return $hash
}
function Get-FoldersStamp($folders) {
  # Stamp over ONLY the mod.info folders (the mod's real content), not
  # the whole download folder. Combines the per-folder content hashes
  # into one hash (sorted, so folder order does not matter).
  # NOTE: stamp basis changed in v402 (mtime -> content hash). The first
  # check after upgrading will list installed mods as updates once
  # (one-time re-baseline), then settle.
  $hashes = @()
  foreach ($f in $folders) {
    $hashes += [string](Get-ContentStamp $f.FullName)
  }
  $hashes = @($hashes | Sort-Object)
  $combined = [string]::Join('|', $hashes)
  try { Add-Type -AssemblyName System.Security -ErrorAction SilentlyContinue } catch { }
  $sha = [System.Security.Cryptography.SHA256]::Create()
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($combined)
  $hash = [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '')
  $sha.Dispose()
  return $hash
}

function Get-ModInfoId($modInfoPath) {
  try {
    $c = Get-Content $modInfoPath -Raw -ErrorAction Stop
    $m = [regex]::Match($c, '(?m)^\s*id\s*=\s*(.+?)\s*$')
    if ($m.Success) { return $m.Groups[1].Value.Trim() }
  } catch { }
  return ''
}

function Test-ModVersionMatches([string]$modInfoPath) {
  # True if this mod.info's version range includes the running game
  # build (same test as the Compatibility report's version check:
  # versionMax int < build = will not load; versionMin int >
  # build = will not load). Missing version info = keep (cannot
  # determine - never drop on a guess).
  $raw = ''
  try { $raw = Get-Content $modInfoPath -Raw -ErrorAction Stop } catch { return $true }
  $vMin = ''; $vMax = ''
  $mmMin = [regex]::Match($raw, '(?m)^\s*versionMin\s*=\s*(.+?)\s*$')
  if ($mmMin.Success) { $vMin = $mmMin.Groups[1].Value.Trim() }
  $mmMax = [regex]::Match($raw, '(?m)^\s*versionMax\s*=\s*(.+?)\s*$')
  if ($mmMax.Success) { $vMax = $mmMax.Groups[1].Value.Trim() }
  $build = 42
  try { $build = [int]$GameBuild } catch { }
  if ($vMax -ne '') {
    $mMax = [regex]::Match($vMax, '^\d+')
    if ($mMax.Success -and [int]$mMax.Value -lt $build) { return $false }
  }
  if ($vMin -ne '') {
    $mMin = [regex]::Match($vMin, '^\d+')
    if ($mMin.Success -and [int]$mMin.Value -gt $build) { return $false }
  }
  return $true
}

function Select-KeptVariants($variantDirs, $storedVariants, [string]$modName, [switch]$DeferPicker, [switch]$ForcePicker) {
  # Auto-pick matching game version + manual pick among same-version
  # variants. Shared by Install-Mod and Install-FoundUpdates (updates
  # must respect the pick, or they undo it).
  # Returns @{ Folders; CarryVariants; DroppedIds }.
  # - Version filter: drop variants whose version range excludes the
  #   running build (Test-ModVersionMatches). Fallback to all if none match.
  # - Same-version picker (GUI only): if >1 compatible variant remains,
  #   show the picker - UNLESS the variants are dependency-linked
  #   (one variant's require= names another in the same item = a core
  #   + module family, not alternatives - keep all, never ask).
  #   The choice is stored (variants = kept Mod IDs);
  #   a NEW variant (not in the stored set) re-opens the picker.
  #   Cancel / empty / failed = keep all, choice unchanged.
  # - CarryVariants = the Mod IDs to store in the install-map entry
  #   (variants), or $null when no choice was ever recorded.
  # - DeferPicker: do NOT show the per-mod picker. When a decision
  #   would be needed (NeedsPicker), return Deferred = $true with the
  #   version-matched Folders + Candidates, so a batch can collect
  #   every pending decision and show ONE consolidated picker
  #   (Show-GuiConsolidatedVariantPicker) instead of one popup per
  #   mod. When no decision is needed, Deferred = $false and the
  #   result is final (install all / stored choice).
  # - ForcePicker: offer the picker even when a stored choice already
  #   covers every variant (Manage variants - the user is asking to
  #   REVISE an existing choice, not just decide a new one). The
  #   stored choice is pre-ticked, so the picker opens showing the
  #   current selection. Install does NOT use this (it skips the
  #   picker when a stored choice covers all - re-ask only on a
  #   NEW variant).
  # - DroppedIds = Mod IDs dropped by either step (caller removes
  #   their already-installed folders, scoped to its own map entry;
  #   Install-FoundUpdates deletes ALL old folders anyway, so it
  #   ignores DroppedIds).
  $folders = @($variantDirs)
  $droppedIds = @()
  $abortBatch = $false
  $deferred = $false
  $deferCands = $null
  $verKept = @(); $verDropped = @()
  foreach ($m in $folders) {
    if (Test-ModVersionMatches (Join-Path $m.FullName 'mod.info')) { $verKept += $m } else { $verDropped += $m }
  }
  if ($verKept.Count -gt 0 -and $verDropped.Count -gt 0) {
    $droppedIds += @($verDropped | ForEach-Object { Get-ModInfoId (Join-Path $_.FullName 'mod.info') } | Where-Object { $_ -ne '' })
    $folders = $verKept
    Write-Host ("  Kept " + $verKept.Count + " variant(s) matching game build " + $GameBuildFull + " (dropped " + $verDropped.Count + " non-matching: " + (($verDropped | ForEach-Object { $_.Name }) -join ', ') + ")") -ForegroundColor DarkGray
  }
  $carryVariants = $null
  if ($storedVariants) { $carryVariants = @($storedVariants) }
  if ($script:GuiMode -and $folders.Count -gt 1) {
    $varCands = @()
    for ($vi = 0; $vi -lt $folders.Count; $vi++) {
      $vm = $folders[$vi]
      $vMi = Join-Path $vm.FullName 'mod.info'
      $vRaw = ''
      try { $vRaw = Get-Content $vMi -Raw -ErrorAction Stop } catch { }
      $vName = $vm.Name
      $mName = [regex]::Match($vRaw, '(?m)^\s*name\s*=\s*(.+?)\s*$')
      if ($mName.Success) { $vName = $mName.Groups[1].Value.Trim() }
      $vMin = ''; $vMax = ''
      $mMin = [regex]::Match($vRaw, '(?m)^\s*versionMin\s*=\s*(.+?)\s*$')
      if ($mMin.Success) { $vMin = $mMin.Groups[1].Value.Trim() }
      $mMax = [regex]::Match($vRaw, '(?m)^\s*versionMax\s*=\s*(.+?)\s*$')
      if ($mMax.Success) { $vMax = $mMax.Groups[1].Value.Trim() }
      $buildHint = 'All builds'
      if ($vMax -ne '') {
        $bMax = [regex]::Match($vMax, '^\d+')
        if ($bMax.Success) { $buildHint = ('Build ' + $bMax.Value) }
      } elseif ($vMin -ne '') {
        $bMin = [regex]::Match($vMin, '^\d+')
        if ($bMin.Success) { $buildHint = ('Build ' + $bMin.Value + '+') }
      }
      $vModId = [string](Get-ModInfoId $vMi)
      # Pre-select: all when no stored choice; stored variants selected,
      # new variants unselected when a choice exists (IsChecked must be
      # set at construction - PSCustomObject cannot add it later).
      $vChecked = (-not $storedVariants) -or ($storedVariants -contains $vModId)
      # Description for the detail pane (click a row to read it): what
      # this variant DOES (e.g. NORUST vs JUST TEXTURES vs full). The
      # Name column alone does not explain the difference. Falls back
      # to the folder name when the mod.info has no description.
      $vDesc = ''
      $mDesc = [regex]::Match($vRaw, '(?m)^\s*description\s*=\s*(.+?)\s*$')
      if ($mDesc.Success) { $vDesc = $mDesc.Groups[1].Value.Trim() }
      # require= list (same parse as the Compatibility report) - used
      # below to detect a core + module family.
      $vReqIds = @()
      $rM = [regex]::Match($vRaw, '(?m)^\s*require\s*=\s*(.+?)\s*$')
      if ($rM.Success) { $vReqIds = @($rM.Groups[1].Value -split '[,;]' | ForEach-Object { $_.Trim().TrimStart('\') } | Where-Object { $_ -ne '' }) }
      # Detail pane info card: description (what it does) + the
      # decision facts (which folder, exact version range, what it
      # requires). The Name / Build columns alone do not show these,
      # and the user cannot tell variants apart without them.
      $vVerRange = 'All builds'
      if ($vMin -ne '' -and $vMax -ne '') { $vVerRange = ($vMin + ' - ' + $vMax) }
      elseif ($vMin -ne '') { $vVerRange = ($vMin + '+') }
      elseif ($vMax -ne '') { $vVerRange = ('up to ' + $vMax) }
      # Description mentions: authors often state a dependency in
      # the description ("To work, you need the mod X") WITHOUT a
      # machine-readable require= line. The game enforces only
      # require=, so description mentions are NOT used for family
      # detection or the Compatibility report - they are shown
      # here (labeled) so the user is not misled by "Requires:
      # None" when the description clearly names a dependency.
      $vDescReqIds = @()
      foreach ($pat in @('(?i)needs?\s+(?:the\s+)?mod\s+', '(?i)requires?\s*:\s*', '(?i)requires?\s+(?:the\s+)?mod\s+', '(?i)depends?\s+on\s+(?:the\s+)?mod\s+')) {
        $dm = [regex]::Match($vDesc, $pat)
        if ($dm.Success) {
          $rest = $vDesc.Substring($dm.Index + $dm.Length)
          $endM = [regex]::Match($rest, '(\.|,|;|\s+to\s+)')
          if ($endM.Success) { $rest = $rest.Substring(0, $endM.Index) }
          foreach ($part in ($rest -split '\s+and\s+|\s*&\s*|\s*\+\s*')) {
            $nm = $part.Trim().Trim('"', "'").Trim()
            # Skip sentence fragments ("you need the mod to be
            # enabled") - a mod name starts with an uppercase
            # letter, a digit, or a bracket, not a lowercase word.
            # -cnotmatch (case-SENSITIVE): plain -match is
            # case-insensitive, so 'M' would match '^[a-z]' and
            # every name would be filtered out.
            if ($nm -ne '' -and $nm.Length -le 60 -and $nm -cnotmatch '^[a-z]') { $vDescReqIds += $nm }
          }
        }
      }
      $vDescReqIds = @($vDescReqIds | Select-Object -Unique)
      $vReqText = 'None'
      if (@($vReqIds).Count -gt 0) { $vReqText = ($vReqIds -join ', ') }
      if (@($vDescReqIds).Count -gt 0) {
        $dTxt = ($vDescReqIds -join ', ') + ' (from description)'
        if ($vReqText -eq 'None') { $vReqText = $dTxt } else { $vReqText = ($vReqText + '; also from description: ' + ($vDescReqIds -join ', ')) }
      }
      $vInfo = ('Folder: ' + [string]$vm.Name + ' | Versions: ' + $vVerRange + ' | Requires: ' + $vReqText)
      $vDetails = $vInfo
      if ($vDesc -ne '') { $vDetails = ($vDesc + "`n`n" + $vInfo) }
      $varCands += [PSCustomObject]@{ Name = [string]$vName; WorkshopId = $vModId; Cat = [string]$buildHint; Details = $vDetails; VariantIndex = $vi; IsChecked = [bool]$vChecked; RequireIds = $vReqIds }
    }
    $currentIds = @($varCands | ForEach-Object { [string]$_.WorkshopId })
    $hasNewVariant = $false
    if ($storedVariants) {
      foreach ($cid in $currentIds) { if ($storedVariants -notcontains $cid) { $hasNewVariant = $true; break } }
    }
    # Module family check: if any variant's require= names another
    # variant in this same Workshop item, the set is a core + module
    # family (e.g. Medicine Moodles + Skill Requirements), NOT
    # alternatives (red vs blue). Never offer to drop one member of a
    # family - dropping a required module breaks the dependent.
    $hasIntraDep = $false
    $idSet = @{}
    foreach ($cid in $currentIds) { $idSet[$cid] = $true }
    foreach ($vc in $varCands) {
      foreach ($rid in @($vc.RequireIds)) {
        if ($idSet.ContainsKey($rid) -and $rid -ne [string]$vc.WorkshopId) { $hasIntraDep = $true; break }
      }
      if ($hasIntraDep) { break }
    }
    if ($hasIntraDep) { Write-Host ("  Variant picker skipped - variants are dependency-linked (module family, keeping all).") -ForegroundColor DarkGray }
    $showPicker = ((-not $storedVariants) -or $hasNewVariant -or $ForcePicker) -and -not $hasIntraDep
    if ($showPicker -and $DeferPicker) {
      # Batch mode: defer the decision (no popup). The caller records
      # the pending mod (folders + candidates + stored choice) and the
      # consolidated picker decides it after the first pass.
      $deferred = $true
      $deferCands = $varCands
    }
    if ($showPicker -and -not $DeferPicker) {
      $pickRes = Show-GuiWpfPicker ('Select versions to keep - ' + $modName) ('This Workshop item contains multiple versions compatible with build ' + $GameBuildFull + '. Select the versions to keep. Unselected versions will not be installed (their folders will be removed if already installed).') $varCands @(@{ Header = 'Name'; Property = 'Name'; Width = 500 }, @{ Header = 'Mod ID'; Property = 'WorkshopId'; Width = 300 }, @{ Header = 'Build'; Property = 'Cat'; Width = 150 }) 'Keep Selected' -ShowCancelAll
      # Cancel all: the user changed their mind - ABORT the whole
      # batch (not just this picker). The flag propagates up: Install-Mod
      # returns $false, and every batch loop breaks. It is reset at
      # each batch entry point (Install selected / Check for updates /
      # Manage variants).
      if ($pickRes -and $pickRes.CancelAll) { $script:AbortVariantBatch = $true; $abortBatch = $true }
      # Robust selection check: @($obj.Prop) with a $null property has
      # Count 1 (not 0), so a bare @(...).Count test treats Cancel
      # (Selected = $null) as a selection. Filter out $nulls first.
      $selItems = @($pickRes.Selected | Where-Object { $_ -ne $null })
      if ($pickRes -and -not $pickRes.Failed -and @($selItems).Count -gt 0) {
        $selIds = @($selItems | ForEach-Object { [string]$_.WorkshopId })
        $keepIdx = @($selItems | ForEach-Object { [int]$_.VariantIndex })
        $keepSet = @{}
        foreach ($ki in $keepIdx) { $keepSet[$ki] = $true }
        $pickedMods = @(); $unpickedMods = @()
        for ($vi = 0; $vi -lt $folders.Count; $vi++) {
          if ($keepSet.ContainsKey($vi)) { $pickedMods += $folders[$vi] } else { $unpickedMods += $folders[$vi] }
        }
        if ($unpickedMods.Count -gt 0) {
          $droppedIds += @($unpickedMods | ForEach-Object { Get-ModInfoId (Join-Path $_.FullName 'mod.info') } | Where-Object { $_ -ne '' })
        }
        $folders = $pickedMods
        $carryVariants = @($selIds)
        Write-Host ("  Keeping " + $pickedMods.Count + " of " + $varCands.Count + " variant(s) (user selection).") -ForegroundColor DarkGray
      }
    }
  }
  if ($folders.Count -eq 1 -and $storedVariants) {
    $singleId = Get-ModInfoId (Join-Path $folders[0].FullName 'mod.info')
    if ($singleId -ne '') { $carryVariants = @($singleId) }
  }
  return [PSCustomObject]@{ Folders = $folders; CarryVariants = $carryVariants; DroppedIds = $droppedIds; AbortBatch = $abortBatch; Deferred = $deferred; Candidates = $deferCands; StoredVariants = $storedVariants }
}

function Get-ConDecisions($modRows) {
  # Build the consolidated picker's Decisions hashtable from the top
  # rows' candidate IsChecked states. A plain named function (not a
  # scriptblock variable invoked via &) - the & $var pattern fails
  # inside WPF event handlers when the variable resolves to $null.
  $dec = @{}
  foreach ($mr in $modRows) {
    $ki = @(); $kid = @()
    foreach ($vc in @($mr.Candidates)) { if ([bool]$vc.IsChecked) { $ki += [int]$vc.VariantIndex; $kid += [string]$vc.WorkshopId } }
    $dec[[string]$mr.WorkshopId] = @{ KeptIndices = $ki; KeptIds = $kid }
  }
  return $dec
}

function Refresh-ConKeptColumn($modRows, $modsList) {
  # Recompute every top row's Kept text (All kept / N of M kept /
  # Skipped) and refresh the top table. NEW array reference: re-
  # assigning the same array does not regenerate the rows (WPF
  # reuses the stale containers). Preserve the selection.
  foreach ($mr in $modRows) {
    $k = @($mr.Candidates | Where-Object { [bool]$_.IsChecked }).Count
    $t = $mr.Candidates.Count
    if ($k -eq $t) { $mr.Kept = 'All kept' }
    elseif ($k -eq 0) { $mr.Kept = 'Skipped' }
    else { $mr.Kept = ($k + ' of ' + $t + ' kept') }
  }
  $selIdx = $modsList.SelectedIndex
  $modsList.ItemsSource = @($modRows)
  $modsList.SelectedIndex = $selIdx
}

$script:NoGripperLoadedHandler = $null
function Add-NoGripperHandler($window) {
  # Collapse the resize-gripper Thumb on headers using the NoGripperHeader
  # style, while keeping the NATIVE header template (pixel-perfect match
  # with the other headers - no custom drawing to drift out of sync).
  # Must run after the window's XAML is loaded (style exists in resources).
  if (-not $window) { return }
  try {
    if ($script:NoGripperLoadedHandler -eq $null) {
      $script:NoGripperLoadedHandler = [System.Windows.RoutedEventHandler]{
        param($sender, $e)
        try {
          $thumb = $sender.Template.FindName('PART_HeaderGripper', $sender)
          if ($thumb -ne $null) { $thumb.Visibility = [System.Windows.Visibility]::Collapsed }
        } catch { }
      }
    }
    $style = $window.FindResource('NoGripperHeader')
    if ($style -ne $null) {
      $setter = New-Object System.Windows.EventSetter([System.Windows.FrameworkElement]::LoadedEvent, $script:NoGripperLoadedHandler)
      $style.Setters.Add($setter)
    }
  } catch { }
}

function Show-GuiConsolidatedVariantPicker($pendingMods) {
  # ONE dialog for every multi-variant mod in a batch (replaces one
  # popup per mod). Top table = the mods with variants; click a mod
  # to see its variants in the BOTTOM table (same GridView pattern as
  # the picker, checkbox + description detail pane). Tick the
  # versions to keep for EACH mod, then Keep selected once.
  # $pendingMods: @( @{ WorkshopId; Name; Candidates } ) where
  #   Candidates are the variant PSCustomObjects from
  #   Select-KeptVariants -DeferPicker (Name, WorkshopId, Cat, Details,
  #   VariantIndex, IsChecked).
  # Returns @{ Decisions; CancelAll; Cancelled } where Decisions =
  #   @{ WorkshopId -> @{ KeptIndices = @(int); KeptIds = @(string) } }.
  # Cancel = keep ALL versions for every mod (continue the batch).
  # Cancel all = abort the whole batch (AbortVariantBatch).
  # A mod with ZERO versions ticked is SKIPPED (not installed).
  if (@($pendingMods).Count -eq 0) { return [PSCustomObject]@{ Decisions = @{}; CancelAll = $false; Cancelled = $false } }
  try {
    Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
    Add-Type -AssemblyName PresentationCore -ErrorAction Stop
    Add-Type -AssemblyName WindowsBase -ErrorAction Stop
    $modRows = @()
    for ($mi = 0; $mi -lt $pendingMods.Count; $mi++) {
      $pm = $pendingMods[$mi]
      $cands = @($pm.Candidates)
      $k = @($cands | Where-Object { [bool]$_.IsChecked }).Count
      $kept = 'All kept'
      if ($k -eq 0) { $kept = 'Skipped' }
      elseif ($k -lt $cands.Count) { $kept = ($k + ' of ' + $cands.Count + ' kept') }
      $modRows += [PSCustomObject]@{ Index = $mi; Name = [string]$pm.Name; WorkshopId = [string]$pm.WorkshopId; Kept = $kept; Candidates = $cands }
    }
    [xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Select versions to keep" Width="1020" Height="640" WindowStartupLocation="CenterScreen" ResizeMode="NoResize">
  <Window.Resources>
    <Style x:Key="NoGripperHeader" TargetType="GridViewColumnHeader" BasedOn="{StaticResource {x:Type GridViewColumnHeader}}">
      <Setter Property="Cursor" Value="Arrow"/>
      <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True">
          <Setter Property="Background">
            <Setter.Value>
              <LinearGradientBrush StartPoint="0,0" EndPoint="0,1">
                <GradientStop Color="#E3F7FF" Offset="0"/>
                <GradientStop Color="#BAEAFD" Offset="1"/>
              </LinearGradientBrush>
            </Setter.Value>
          </Setter>
        </Trigger>
      </Style.Triggers>
    </Style>
  </Window.Resources>
  <Grid Margin="10">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>
    <TextBlock Grid.Row="0" x:Name="ConInstruction" Margin="0,0,0,6" TextWrapping="Wrap"/>
    <ListView ScrollViewer.HorizontalScrollBarVisibility="Disabled" Grid.Row="1" x:Name="ConMods" SelectionMode="Single">
      <ListView.View><GridView x:Name="ConModsGridView" AllowsColumnReorder="False"/></ListView.View>
    </ListView>
    <ListView ScrollViewer.HorizontalScrollBarVisibility="Disabled" Grid.Row="2" x:Name="ConVariants" SelectionMode="Single" Margin="0,8,0,0">
      <ListView.View><GridView x:Name="ConVariantsGridView" AllowsColumnReorder="False"/></ListView.View>
    </ListView>
    <Border Grid.Row="3" BorderBrush="Gray" BorderThickness="1" Margin="0,8,0,0" MaxHeight="80">
      <TextBox x:Name="ConDetail" TextWrapping="Wrap" Margin="4" IsReadOnly="True" BorderThickness="0" Background="Transparent" VerticalScrollBarVisibility="Auto" Text="Click a version below to read its full description here."/>
    </Border>
    <StackPanel Grid.Row="4" Orientation="Horizontal" Margin="0,8,0,0">
      <Button x:Name="ConSelectAll" Content="Select All Versions" Padding="12,4" Margin="0,0,8,0"/>
      <Button x:Name="ConClear" Content="Deselect All Versions" Padding="12,4" Margin="0,0,8,0"/>
      <Button x:Name="ConWorkshop" Content="View Mod's Page" Padding="12,4" Margin="180,0,8,0"/>
      <Button x:Name="ConKeep" Content="Apply Selection" Padding="12,4" Margin="0,0,8,0"/>
      <Button x:Name="ConCancel" Content="Keep All Versions" Padding="12,4" Margin="0,0,8,0"/>
      <Button x:Name="ConCancelAll" Content="Abort Batch" Padding="12,4"/>
    </StackPanel>
  </Grid>
</Window>
'@
    $reader = New-Object System.Xml.XmlNodeReader($xaml)
    $window = [System.Windows.Markup.XamlReader]::Load($reader)
    Add-NoGripperHandler $window
    $window.FindName('ConInstruction').Text = 'These Workshop items have multiple versions compatible with build ' + $GameBuildFull + '. Select a mod above to see its versions below, then tick the versions to keep for each mod. Untick all versions for a mod to skip installing it. Select all versions / Deselect all versions apply to the mod highlighted above. Keep selected versions confirms the ticked versions for EVERY mod in this list. Keep All Versions keeps every version for every mod; Abort Batch stops the whole batch.'
    if ($script:GuiWindow) { $window.Owner = $script:GuiWindow }
    Set-DialogWindowIcon $window
    $modsList = $window.FindName('ConMods')
    $varsList = $window.FindName('ConVariants')
    $modsGrid = $window.FindName('ConModsGridView')
    $varsGrid = $window.FindName('ConVariantsGridView')
    $noGripper = $window.FindResource('NoGripperHeader')
    # Top table: Name / Workshop ID / Kept (no checkbox - it is navigation,
    # the picking happens in the bottom table).
    $c1 = New-Object System.Windows.Controls.GridViewColumn; $c1.Header = 'Name'; $c1.Width = 500; $c1.DisplayMemberBinding = New-Object System.Windows.Data.Binding('Name'); [void]$modsGrid.Columns.Add($c1)
    $c2 = New-Object System.Windows.Controls.GridViewColumn; $c2.Header = 'Workshop ID'; $c2.Width = 300; $c2.DisplayMemberBinding = New-Object System.Windows.Data.Binding('WorkshopId'); [void]$modsGrid.Columns.Add($c2)
    $c3 = New-Object System.Windows.Controls.GridViewColumn; $c3.Header = 'Kept'; $c3.Width = 150; $c3.DisplayMemberBinding = New-Object System.Windows.Data.Binding('Kept'); $c3.HeaderContainerStyle = $noGripper; [void]$modsGrid.Columns.Add($c3)
    Register-LastColumnFill $modsList
    # Bottom table: standard checkbox + Name / Mod ID / Build.
    $checkTpl = [System.Windows.Markup.XamlReader]::Parse('<DataTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"><CheckBox IsChecked="{Binding IsChecked}" HorizontalAlignment="Center" VerticalAlignment="Center"/></DataTemplate>')
    Build-StandardGridColumns $varsGrid @(@{ Header = 'Name'; Property = 'Name'; Width = 500 }, @{ Header = 'Mod ID'; Property = 'WorkshopId'; Width = 300 }, @{ Header = 'Build'; Property = 'Cat'; Width = 150 }) $checkTpl $noGripper
    Register-LastColumnFill $varsList
    # Top selection: show this mod's variants below.
    $modsList.Add_SelectionChanged({
      param($sender, $e)
      $w = [System.Windows.Window]::GetWindow($sender); if (-not $w) { return }
      $sel = $sender.SelectedItem
      $vl = $w.FindName('ConVariants'); if ($vl) { if ($sel) { $vl.ItemsSource = @($sel.Candidates) } else { $vl.ItemsSource = @() } }
      $w.FindName('ConDetail').Text = 'Click a version below to read its full description here.'
      # Standard: View this mod on Workshop needs a highlighted row
      # with a numeric Workshop ID whose Name is not just the ID.
      $w.FindName('ConWorkshop').IsEnabled = ($null -ne $sel -and [string]$sel.WorkshopId -match '^\d+$' -and [string]$sel.Name -ne '' -and [string]$sel.Name -ne [string]$sel.WorkshopId)
    })
    # Bottom checkbox click: write IsChecked back to the candidate row.
    $varsList.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, [System.Windows.RoutedEventHandler]{
      param($sender, $e)
      $cb = $e.OriginalSource -as [System.Windows.Controls.CheckBox]
      if ($cb -and $cb.DataContext) { $cb.DataContext.IsChecked = [bool]$cb.IsChecked; $w = [System.Windows.Window]::GetWindow($sender); if ($w) { $ml = $w.FindName('ConMods'); if ($ml) { Refresh-ConKeptColumn @($ml.ItemsSource) $ml } } }
    })
    # Bottom row click: show the variant's description in the detail pane.
    $varsList.Add_SelectionChanged({
      param($sender, $e)
      $sel = $sender.SelectedItem
      $txt = 'Click a version below to read its full description here.'
      if ($sel) {
        if ([string]$sel.Details -ne '') { $txt = [string]$sel.Details }
        elseif ([string]$sel.Name -ne '') { $txt = [string]$sel.Name }
      }
      $w = [System.Windows.Window]::GetWindow($sender); if ($w) { $w.FindName('ConDetail').Text = $txt }
    })
    $window.FindName('ConSelectAll').Add_Click({ param($sender, $e); $w = [System.Windows.Window]::GetWindow($sender); if (-not $w) { return }; $ml = $w.FindName('ConMods'); $vl = $w.FindName('ConVariants'); if (-not $ml -or -not $vl) { return }; $cur = $ml.SelectedItem; if ($cur) { foreach ($r in @($cur.Candidates)) { $r.IsChecked = $true }; $vl.ItemsSource = @($cur.Candidates); Refresh-ConKeptColumn @($ml.ItemsSource) $ml } })
    $window.FindName('ConClear').Add_Click({ param($sender, $e); $w = [System.Windows.Window]::GetWindow($sender); if (-not $w) { return }; $ml = $w.FindName('ConMods'); $vl = $w.FindName('ConVariants'); if (-not $ml -or -not $vl) { return }; $cur = $ml.SelectedItem; if ($cur) { foreach ($r in @($cur.Candidates)) { $r.IsChecked = $false }; $vl.ItemsSource = @($cur.Candidates); Refresh-ConKeptColumn @($ml.ItemsSource) $ml } })
    $result = @{ Decisions = $null; CancelAll = $false; Cancelled = $false }
    $window.Tag = $result
    # Store the result hashtable on the window's Tag so the
    # button handlers can reach it via GetWindow($sender) without
    # capturing ANY variable. WPF event handlers cannot reliably
    # resolve captured variables (function-local OR $script:) -
    # they come back $null and a $null.ItemsSource / FindName()
    # throws on deselect / remove-all. Every handler below
    # derives its controls from $sender only (scope-free).
    $window.FindName('ConWorkshop').Add_Click({ param($sender, $e); $w = [System.Windows.Window]::GetWindow($sender); if (-not $w) { return }; $ml = $w.FindName('ConMods'); if (-not $ml) { return }; $cur = $ml.SelectedItem; if ($cur -and [string]$cur.WorkshopId -match '^\d+$' -and [string]$cur.Name -ne '' -and [string]$cur.Name -ne [string]$cur.WorkshopId) { Start-Process ('https://steamcommunity.com/sharedfiles/filedetails/?id=' + [string]$cur.WorkshopId) } })
    $window.FindName('ConKeep').Add_Click({ param($sender, $e); $w = [System.Windows.Window]::GetWindow($sender); if (-not $w) { return }; $ml = $w.FindName('ConMods'); $res = $w.Tag; if ($res -and $ml) { $res.Decisions = (Get-ConDecisions @($ml.ItemsSource)) }; $w.Close() })
    $window.FindName('ConCancel').Add_Click({ param($sender, $e); $w = [System.Windows.Window]::GetWindow($sender); if (-not $w) { return }; $ml = $w.FindName('ConMods'); $res = $w.Tag; if ($res) { $res.Cancelled = $true }; if ($ml) { foreach ($mr in @($ml.ItemsSource)) { foreach ($vc in @($mr.Candidates)) { $vc.IsChecked = $true } } }; if ($res -and $ml) { $res.Decisions = (Get-ConDecisions @($ml.ItemsSource)) }; $w.Close() })
    $window.FindName('ConCancelAll').Add_Click({ param($sender, $e); $w = [System.Windows.Window]::GetWindow($sender); if (-not $w) { return }; $res = $w.Tag; if ($res) { $res.CancelAll = $true }; $w.Close() })
    $modsList.ItemsSource = $modRows
    if ($modRows.Count -gt 0) { $modsList.SelectedIndex = 0 }
    [void]$window.ShowDialog()
    if ($result.CancelAll) { return [PSCustomObject]@{ Decisions = $null; CancelAll = $true; Cancelled = $false } }
    if ($result.Decisions -eq $null) { $result.Decisions = (Get-ConDecisions $modRows) }
    return [PSCustomObject]@{ Decisions = $result.Decisions; CancelAll = $false; Cancelled = $result.Cancelled }
  } catch {
    $script:LastPickerError = $_.Exception.Message
    # Picker failed to build - keep ALL versions for every pending
    # mod (same fallback as the per-mod picker: failure = keep all,
    # never drop on a guess).
    $dec = @{}
    foreach ($pm in @($pendingMods)) {
      $ki = @(); $kid = @()
      foreach ($vc in @($pm.Candidates)) { $ki += [int]$vc.VariantIndex; $kid += [string]$vc.WorkshopId }
      $dec[[string]$pm.WorkshopId] = @{ KeptIndices = $ki; KeptIds = $kid }
    }
    return [PSCustomObject]@{ Decisions = $dec; CancelAll = $false; Cancelled = $false; Failed = $true }
  }
}

function Get-ShallowModInfos {
  # mod.info files at depth 1-2 only (mods/Top/mod.info, mods/Top/42/mod.info,
  # mods/Top/common/mod.info) - every realistic mod layout. Avoids a full
  # recursive walk (deep media/ trees make one walk take 10-30s on 264
  # mods), so startup adopt stays fast and the GUI loads quickly.
  $out = @()
  if (-not (Test-Path $ModsDir)) { return @() }
  foreach ($top in @(Get-ChildItem $ModsDir -Directory -ErrorAction SilentlyContinue)) {
    $mi = Join-Path $top.FullName 'mod.info'
    if (Test-Path $mi) { $out += Get-Item $mi }
    foreach ($sub in @(Get-ChildItem $top.FullName -Directory -ErrorAction SilentlyContinue)) {
      $mi2 = Join-Path $sub.FullName 'mod.info'
      if (Test-Path $mi2) { $out += Get-Item $mi2 }
    }
  }
  return $out
}

function Get-ModInfoName($modInfoPath) {
  try {
    $c = Get-Content $modInfoPath -Raw -ErrorAction Stop
    $m = [regex]::Match($c, '(?m)^\s*name\s*=\s*(.+?)\s*$')
    if ($m.Success) { return $m.Groups[1].Value.Trim() }
  } catch { }
  return ''
}

function Get-InstalledModStamp($topFolderPath) {
  # Stamp for an already-on-disk mod: max mtime over its mod.info dirs
  # (same basis as Find-ModUpdates' download-folder stamp). Used by
  # adopt (GUI button + startup) so the map entry has a real stamp.
  # NOTE: Get-FoldersStamp needs objects with .FullName - passing a
  # bare string yields $null and a stamp of 0 (v234 Adopt bug).
  if (-not (Test-Path $topFolderPath)) { return 0 }
  $dirs = @(Get-ChildItem $topFolderPath -Directory -Recurse | Where-Object { Test-Path (Join-Path $_.FullName 'mod.info') })
  if (Test-Path (Join-Path $topFolderPath 'mod.info')) { $dirs = @(@(Get-Item $topFolderPath) + $dirs) }
  return (Get-FoldersStamp $dirs)
}

function Repair-GenericModFolders {
  if (-not (Test-Path $ModsDir)) { return }
  $dirs = @(Get-ChildItem $ModsDir -Directory | Where-Object { $_.Name -match '^(?i)(\d{10}([_.].*)?|\d+(\.\d+)*(_\d+(\.\d+)*)?|common|mods?|main|default)$' })
  if ($dirs.Count -eq 0) { return }
  $map = Get-InstallMap
  $renamed = 0
  foreach ($d in $dirs) {
    $mi = Join-Path $d.FullName 'mod.info'
    if (-not (Test-Path $mi)) { continue }
    # Pure version folders (42.20, 42.12_42.12) may have mixed content from overwrites - delete them
    # Workshop-ID folders (1911132112_42.12) are single-workshop, go through normal rename path
    if (($d.Name -match '\.') -and ($d.Name -notmatch '^\d{10}')) {
      Remove-Item $d.FullName -Recurse -Force -ErrorAction SilentlyContinue
      Write-Host ("  Deleted broken version folder '" + $d.Name + "' (reinstall the mod to fix)") -ForegroundColor Yellow
      $renamed++
      continue
    }
    $mid = Get-ModInfoId $mi
    if ($mid -notmatch '^[A-Za-z0-9_.\-]+$') { continue }
    $dest = Join-Path $ModsDir $mid
    if ($d.FullName -ieq $dest) { continue }
    if (Test-Path $dest) {
      # Duplicate: proper folder already exists - verify same mod, then delete the stale copy
      $destId = Get-ModInfoId (Join-Path $dest 'mod.info')
      if ($destId -eq $mid) {
        Remove-Item $d.FullName -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host ("  Deleted stale duplicate folder '" + $d.Name + "' (proper '" + $mid + "' already installed)") -ForegroundColor Yellow
        $renamed++
      } else {
        Write-Host ("  Skipping generic folder '" + $d.Name + "' - '" + $mid + "' exists but has different id (" + $destId + ")") -ForegroundColor DarkGray
      }
      continue
    }
    Rename-Item $d.FullName $mid -ErrorAction SilentlyContinue
    if (Test-Path $dest) {
      $renamed++
      Write-Host ("  Renamed generic mod folder '" + $d.Name + "' -> '" + $mid + "'") -ForegroundColor Yellow
      if ($map) {
        foreach ($pr in $map.PSObject.Properties) {
          $fl = @($pr.Value.folders)
          $chg = $false
          for ($i = 0; $i -lt $fl.Count; $i++) {
            if ([string]$fl[$i] -ieq $d.Name) { $fl[$i] = $mid; $chg = $true }
          }
          if ($chg) { $pr.Value.folders = $fl }
        }
      }
    }
  }
  if ($renamed -gt 0 -and $map) { Save-InstallMap $map }
}

function Repair-FlattenedMods {
  # The game requires mods/YOURMOD/<build>/mod.info + mods/YOURMOD/common/ - the manager used to
  # flatten version folders (copying <build>/* directly to root), which makes PZ ignore the mod.
  # <build> is $GameBuild (e.g. '42'); version folders look like 42.20.
  if (-not (Test-Path $ModsDir)) { return }
  $verPattern = '^(?i)' + $GameBuild + '\.\d+$'
  foreach ($d in (Get-ChildItem $ModsDir -Directory)) {
    # Case B (un-nest): an earlier repair nested a version folder inside <build>/ (e.g. 42/42.20/).
    # The game loads Lua from <build>/media/, so flatten one level: <build>/<ver>/* -> <build>/*.
    $verDir = Join-Path $d.FullName $GameBuild
    if (Test-Path $verDir) {
      $nested = @(Get-ChildItem $verDir -Directory | Where-Object { $_.Name -match $verPattern -and ((Test-Path (Join-Path $_.FullName 'mod.info')) -or (Test-Path (Join-Path $_.FullName 'media'))) })
      foreach ($n in $nested) {
        Write-Host ("  Un-nesting version folder '" + $d.Name + "/" + $GameBuild + "/" + $n.Name + "' -> '" + $d.Name + "/" + $GameBuild + "/'...") -ForegroundColor Yellow
        foreach ($item in (Get-ChildItem $n.FullName)) {
          Move-Item $item.FullName (Join-Path $verDir $item.Name) -Force -ErrorAction SilentlyContinue
        }
        Remove-Item $n.FullName -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host ("  Fixed nested version folder: " + $d.Name) -ForegroundColor Green
      }
      continue
    }
    # Case A (rename): mod ships code in a version folder (e.g. 42.20/) instead of <build>/.
    # The game loads versioned content from <build>/ only, so rename the folder to <build>.
    # (A-Life 1.4.2 ships 42.20/.)
    $verFolders = @(Get-ChildItem $d.FullName -Directory | Where-Object { $_.Name -match $verPattern -and (Test-Path (Join-Path $_.FullName 'mod.info')) })
    if ($verFolders.Count -gt 0) {
      $vf = @($verFolders | Sort-Object { [version]$_.Name } -Descending)[0]
      Write-Host ("  Renaming version folder '" + $d.Name + "/" + $vf.Name + "' -> '" + $d.Name + "/" + $GameBuild + "/'...") -ForegroundColor Yellow
      Rename-Item $vf.FullName $GameBuild -ErrorAction SilentlyContinue
      if (Test-Path $verDir) {
        $mi0 = Join-Path $d.FullName 'mod.info'
        if (-not (Test-Path $mi0)) { Copy-Item (Join-Path $verDir 'mod.info') $mi0 -Force -ErrorAction SilentlyContinue }
        Write-Host ("  Fixed version folder: " + $d.Name) -ForegroundColor Green
      }
      continue
    }
    $mi = Join-Path $d.FullName 'mod.info'
    if (-not (Test-Path $mi)) { continue }
    $content = Get-Content $mi -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }
    # Skip mods targeting an older build (e.g. versionMin=41 on B42); repair current-build
    # (versionMin=<build>) and undeclared (likely current build from our list)
    $mmin0 = [regex]::Match($content, '(?m)^\s*versionMin\s*=\s*(\d+)')
    if ($mmin0.Success -and [int]$mmin0.Groups[1].Value -lt [int]$GameBuild) { continue }
    # Flattened = root mod.info + versioned content (media/ or common/) but no <build>/ folder.
    # Model packs (e.g. 6244 Viewpoint models) keep all content in common/ with no media/,
    # so common/ alone must trigger the repair - the old media/-only guard skipped them,
    # leaving PZ unable to list the mod despite all files being on disk.
    $hasMedia = Test-Path (Join-Path $d.FullName 'media')
    $hasCommon = Test-Path (Join-Path $d.FullName 'common')
    if (-not $hasMedia -and -not $hasCommon) { continue }
    Write-Host ("  Repairing B" + $GameBuild + " structure for '" + $d.Name + "'...") -ForegroundColor Yellow
    $verDir = Join-Path $d.FullName $GameBuild
    New-Item -ItemType Directory -Force -Path $verDir | Out-Null
    foreach ($item in (Get-ChildItem $d.FullName)) {
      if ($item.Name -ieq $GameBuild -or $item.Name -ieq 'common') { continue }
      Move-Item $item.FullName (Join-Path $verDir $item.Name) -Force -ErrorAction SilentlyContinue
    }
    $innerInfo = Join-Path $verDir 'mod.info'
    if ((Test-Path $innerInfo) -and (-not (Test-Path $mi))) {
      Copy-Item $innerInfo $mi -Force
    } elseif (Test-Path $innerInfo) {
      Copy-Item $innerInfo $mi -Force
    }
    $common = Join-Path $d.FullName 'common'
    if (-not (Test-Path $common)) { New-Item -ItemType Directory -Force -Path $common | Out-Null }
    Write-Host ("  Fixed B" + $GameBuild + " layout: " + $d.Name) -ForegroundColor Green
  }
}

# Prerequisite map: WorkshopId -> required WorkshopIds (auto-installed before the mod itself)
$DepMap = @{
  '3809306528' = @('3619862853')   # Project Viewpoint -> ZombieBuddy
  '3397396843' = @('3619862853')   # Knox Event Expanded NPC -> ZombieBuddy
  '2459400130' = @('3396446795')   # Dynamic Traits + Expanded Moodles -> Moodle Framework
  '3695874178' = @()               # Dynamic Events (base, no dependencies)
  '3717082142' = @('3695874178')   # Chaos Mod / Dynamic Events Special -> Dynamic Events
}
# ModID -> WorkshopID for generic require= resolution (when a mod needs a dep not in DepMap)
$ModIdToWorkshop = @{
  'ZombieBuddy' = '3619862853'
  'Viewpoint' = '3809306528'
  'PZVoxelStudioViewpoint' = '3810302175'
  'MoodleFramework' = '3396446795'
  'YAPZLib' = '3624971238'
  'DynamicEvents' = '3695874178'
  'WarThunderVehicleLibrary' = '3399660368'
}
$script:DepDepth = 0

function Get-DiskModIdMap {
  # Cached Mod ID -> folder name map for the on-disk mods folder. ONE
  # recursive scan, reused by every dep check in an install run. Without
  # this, Install-Mod rescanned the whole mods folder for EVERY missing
  # dep of EVERY mod - hundreds of full-disk scans on the UI thread, which
  # is what made Install look frozen (blank window) on a 200-mod list.
  # Callers that change disk state clear it (Clear-DiskModIdMap); new
  # installs add their Mod IDs to it as they land.
  if ($script:DiskModIdMap) { return $script:DiskModIdMap }
  $map = @{}
  if (Test-Path $ModsDir) {
    foreach ($chk in @(Get-ChildItem $ModsDir -Recurse -Filter 'mod.info' -File -ErrorAction SilentlyContinue)) {
      $mid = Get-ModInfoId $chk.FullName
      if ($mid -ne '' -and -not $map.ContainsKey($mid)) { $map[$mid] = $chk.Directory.Name }
    }
  }
  $script:DiskModIdMap = $map
  return $map
}
function Clear-DiskModIdMap { $script:DiskModIdMap = $null }

function Test-PreInstallCompatible([string]$WorkshopId, [string]$Name, $keptDirs) {
  # Pre-install compatibility check on the DOWNLOADED mod (SteamCMD
  # cache, before it is copied into the game folder). Mirrors the
  # Compatibility report's per-mod.info checks (empty, UTF-8, version,
  # javaJarFile), but only blocks on UNRESOLVABLE dependencies: a
  # require= mod that is already installed (on disk) or in
  # $ModIdToWorkshop will be auto-installed by the dependency check,
  # so it does not block. Returns @{ Compatible; Reasons }.
  $blocked = @()
  $willInstallDeps = @()
  $multi = (@($keptDirs).Count -gt 1)
  foreach ($dir in @($keptDirs)) {
    $miPath = Join-Path $dir.FullName 'mod.info'
    $fid = Get-ModInfoId $miPath
    $prefix = ''
    if ($multi -and $fid) { $prefix = ($fid + ': ') }
    $raw = ''
    try { $raw = Get-Content $miPath -Raw -ErrorAction Stop } catch { }
    if ($raw -eq '') { $blocked += ($prefix + 'mod.info is empty/unreadable'); continue }
    $utf8Valid = $true
    try {
      $rb = [IO.File]::ReadAllBytes($miPath)
      $dec = [Text.Encoding]::UTF8.GetString($rb)
      if ([Text.Encoding]::UTF8.GetBytes($dec).Length -ne $rb.Length) { $utf8Valid = $false }
    } catch { $utf8Valid = $false }
    if (-not $utf8Valid) { $blocked += ($prefix + 'mod.info has invalid UTF-8 encoding (game may skip it)') }
    $vmin = ''; $vmax = ''
    $mmin = [regex]::Match($raw, '(?m)^\s*versionMin\s*=\s*(.+?)\s*$'); if ($mmin.Success) { $vmin = $mmin.Groups[1].Value.Trim() }
    $mmax = [regex]::Match($raw, '(?m)^\s*versionMax\s*=\s*(.+?)\s*$'); if ($mmax.Success) { $vmax = $mmax.Groups[1].Value.Trim() }
    # Leading-integer compare (same as Test-ModVersionMatches): a
    # decimal cap like versionMax=41.99 still excludes B42.
    $mMaxInt = [regex]::Match($vmax, '^\d+')
    if ($mMaxInt.Success -and [int]$mMaxInt.Value -lt [int]$GameBuild) { $blocked += ($prefix + "versionMax=$vmax is older than B$GameBuild (game will not load it)") }
    else {
      $mMinInt = [regex]::Match($vmin, '^\d+')
      if ($mMinInt.Success -and [int]$mMinInt.Value -gt [int]$GameBuild) { $blocked += ($prefix + "versionMin=$vmin is newer than B$GameBuild (game will not load it)") }
    }
    $mjar = [regex]::Match($raw, '(?m)^\s*javaJarFile\s*=\s*(.+?)\s*$')
    if ($mjar.Success) {
      $jarRel = $mjar.Groups[1].Value.Trim()
      $parentDir = Split-Path $miPath -Parent
      $jarFound = $false
      $modRoot = Split-Path $parentDir -Parent
      $bases = @($parentDir, (Join-Path $parentDir 'common'), (Join-Path $parentDir $GameBuild))
      if ($modRoot) { $bases += $modRoot; $bases += (Join-Path $modRoot 'common'); $bases += (Join-Path $modRoot $GameBuild) }
      foreach ($base in $bases) {
        if (Test-Path (Join-Path $base $jarRel)) { $jarFound = $true; break }
      }
      if (-not $jarFound -and $fid -eq 'ZombieBuddy') {
        $gameJ = Find-GameFolder -AllowPrompt:$false
        if ($gameJ -and (Test-Path (Join-Path $gameJ 'ZombieBuddy.jar'))) { $jarFound = $true }
      }
      if (-not $jarFound) { $blocked += ($prefix + 'references missing file: ' + $jarRel) }
    }
    $reqM = [regex]::Match($raw, '(?m)^\s*require\s*=\s*(.+?)\s*$')
    if ($reqM.Success) {
      $reqIds = @($reqM.Groups[1].Value -split '[,;]' | ForEach-Object { $_.Trim().TrimStart('\') } | Where-Object { $_ -ne '' })
      $diskMap = Get-DiskModIdMap
      foreach ($rid in $reqIds) {
        if ($diskMap.ContainsKey($rid)) { continue }
        if ($ModIdToWorkshop.ContainsKey($rid)) { if ($willInstallDeps -notcontains $rid) { $willInstallDeps += $rid }; continue }
        $blocked += ($prefix + "Missing dependency '$rid' (unknown Workshop ID - cannot resolve it)")
      }
    }
  }
  return @{ Compatible = ($blocked.Count -eq 0); Reasons = $blocked; WillInstallDeps = $willInstallDeps }
}

function Complete-InstallModCore([string]$WorkshopId, [string]$Name, $keptDirs, $carryVariants, $droppedIds, $prop0, [string]$src, [switch]$SkipPreCheck) {
  # Shared tail of an install (used by Install-Mod AND by the
  # deferred path after the consolidated picker decides): dropped-
  # variant folder cleanup, copy, empty rescue, generic dependency
  # check, install-map save, ZombieBuddy agent, B42 repair.
  # $keptDirs: the variant folders to copy (DirectoryInfo, in $src).
  # $droppedIds: Mod IDs dropped by version filter + picker (their
  # already-installed folders are removed, scoped to this item).
  # Pre-install compatibility check: verify the downloaded mod BEFORE
  # copying it into the game folder. On failure, ask "Install anyway?"
  # - No skips this mod (it stays out of the game folder).
  if (-not $SkipPreCheck) {
    $preCheck = Test-PreInstallCompatible $WorkshopId $Name $keptDirs
    if (-not $preCheck.Compatible) {
      if ($script:BatchPreCheckDecisions) {
        # Batch mode: defer the decision - collect for ONE consolidated
        # list at the end (no popup per mod). Dedupe: a mod reached
        # twice in one batch (selected AND a dependency) lists once.
        $already = @($script:PendingPreCheckFailures | Where-Object { [string]$_.WorkshopId -eq [string]$WorkshopId })
        if ($already.Count -eq 0) {
          $script:PendingPreCheckFailures += [PSCustomObject]@{ WorkshopId = [string]$WorkshopId; Name = [string]$Name; KeptDirs = @($keptDirs); CarryVariants = @($carryVariants); DroppedIds = @($droppedIds); Prop0 = $prop0; Src = [string]$src; Reasons = @($preCheck.Reasons); WillInstallDeps = @($preCheck.WillInstallDeps) }
        }
        return 'precheck-deferred'
      }
      $res = Show-GuiMessageBox ("Mod '" + $Name + "' failed the pre-install compatibility check:`n" + ($preCheck.Reasons -join "`n") + "`n`nInstall it anyway?") 'PZ Mod Manager' ([System.Windows.MessageBoxButton]::YesNo) ([System.Windows.MessageBoxImage]::Warning)
      if ($res -ne [System.Windows.MessageBoxResult]::Yes) {
        Write-Host ("  Skipped: " + $Name + " (failed pre-install compatibility check)") -ForegroundColor Yellow
        return $false
      }
    }
  }
  # Remove already-installed folders of dropped variants (scoped to
  # this Workshop item's recorded folders, matched by Mod ID).
  if (@($droppedIds).Count -gt 0 -and $prop0 -and $prop0.Value.folders) {
    foreach ($ef in @($prop0.Value.folders)) {
      $eMi = Join-Path (Join-Path $ModsDir ([string]$ef)) 'mod.info'
      if (@($droppedIds) -contains (Get-ModInfoId $eMi)) {
        $ed = Join-Path $ModsDir ([string]$ef)
        if (Test-Path $ed) { Remove-Item $ed -Recurse -Force -ErrorAction SilentlyContinue }
        Write-Host ("  Removed dropped variant folder: " + $ef) -ForegroundColor DarkGray
      }
    }
  }
  $usedNames = @{}
  $finalNames = @()
  foreach ($m in $keptDirs) {
    $dirName = $m.Name
    if ($dirName -match '^(?i)(\d{10}([_.].*)?|\d+(\.\d+)*(_\d+(\.\d+)*)?|common|mods?|main|default)$') {
      $mid = Get-ModInfoId (Join-Path $m.FullName 'mod.info')
      if ($mid -match '^[A-Za-z0-9_.\-]+$') { $dirName = $mid }
      else { $dirName = ($WorkshopId + '_' + $m.Name) }
    }
    if ($usedNames.ContainsKey($dirName)) { $dirName = ($dirName + '_' + $m.Name) }
    $usedNames[$dirName] = $true
    $dest = Join-Path $ModsDir $dirName
    if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
    $isVerFolder = $m.Name -match '^(?i)(\d{2}(\.\d+)?)$'
    $isCommonFolder = $m.Name -match '^(?i)common$'
    if ($isVerFolder -or $isCommonFolder) {
      # Mod lives in a versioned/common subfolder: the mod root is the PARENT.
      # Copy the WHOLE parent so common/ + version folders survive intact.
      # Old code flattened common/ (dropping 42/) and created an EMPTY common/
      # (dropping real common/ content). For Java mods like Viewpoint that drops
      # the JAR in 42/, so the game cannot load the mod and never lists it.
      $parent = $m.Parent
      [void](Copy-Item $parent.FullName $dest -Recurse -Force)
      $rootInfo = Join-Path $dest 'mod.info'
      if (-not (Test-Path $rootInfo)) { Copy-Item (Join-Path $m.FullName 'mod.info') $rootInfo -Force }
      Write-Host ("  Installed (B" + $GameBuild + " layout, kept common/ + version folders): " + $dirName) -ForegroundColor DarkGray
    } else {
      Copy-Item $m.FullName $dest -Recurse -Force
      Write-Host ("  Installed: " + $dirName) -ForegroundColor DarkGray
    }
    if (-not (Test-Path (Join-Path $dest 'mod.info'))) {
      Write-Host ("  FAILED: copy failed for " + $m.Name + " - not recorded as installed") -ForegroundColor Red
      return $false
    }
    $finalNames += $dirName
  }
  foreach ($dn in $finalNames) {
    $mi2 = Join-Path (Join-Path $ModsDir $dn) 'mod.info'
    $mid2 = Get-ModInfoId $mi2
    $mname = ''
    try {
      $mm = [regex]::Match((Get-Content $mi2 -Raw -ErrorAction Stop), '(?m)^\s*name\s*=\s*(.+?)\s*$')
      if ($mm.Success) { $mname = $mm.Groups[1].Value.Trim() }
    } catch { }
    Write-Host ("  -> id=" + $mid2 + " name=" + $mname) -ForegroundColor Green
    if ($mid2 -ne '' -and $script:DiskModIdMap) { $script:DiskModIdMap[$mid2] = $dn }
  }
  # Rescue empty installs: the download's real content may sit in a sibling folder
  # the mod.info scan never copies (single-mod items), or the cache may be truncated.
  if (-not $script:EmptyRetry) { $script:EmptyRetry = @{} }
  $testEmpty = { param($d) @(Get-ChildItem $d -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'mod.info' -and $_.Extension -notmatch '(?i)\.(png|jpg|jpeg|gif|bmp)$' } | Select-Object -First 1).Count -eq 0 }
  for ($fi = 0; $fi -lt $finalNames.Count; $fi++) {
    $dn = $finalNames[$fi]
    $destDir = Join-Path $ModsDir $dn
    if (-not (& $testEmpty $destDir)) { continue }
    # (a) Sibling rescue (single-mod items only): copy download folders with no mod.info anywhere inside
    if ($finalNames.Count -eq 1) {
      $modSrc = $keptDirs[$fi].FullName
      $modParent = Split-Path $modSrc -Parent
      $cands = @(Get-ChildItem $modParent -Directory -ErrorAction SilentlyContinue)
      if ($modParent -ne $src) { $cands += @(Get-ChildItem $src -Directory -ErrorAction SilentlyContinue) }
      foreach ($cand in $cands) {
        if ($cand.FullName -eq $modSrc) { continue }
        if (Test-Path (Join-Path $destDir $cand.Name)) { continue }
        if ($modSrc -like ($cand.FullName + '\*')) { continue }
        if (@(Get-ChildItem $cand.FullName -Recurse -Filter 'mod.info' -File -ErrorAction SilentlyContinue | Select-Object -First 1).Count -gt 0) { continue }
        Copy-Item $cand.FullName $destDir -Recurse -Force
        Write-Host ("  Rescued sibling content '" + $cand.Name + "' into " + $dn) -ForegroundColor Cyan
      }
    }
    if (& $testEmpty $destDir) {
      # (b) Still empty: truncated cache - clear it and retry the whole install once
      if (-not $script:EmptyRetry[$WorkshopId]) {
        $script:EmptyRetry[$WorkshopId] = $true
        Write-Host ("  " + $dn + " installed empty - clearing stale download cache and retrying once...") -ForegroundColor Yellow
        Remove-Item $src -Recurse -Force -ErrorAction SilentlyContinue
        return (Install-Mod $WorkshopId $Name)
      }
      Write-Host ("  WARNING: " + $dn + " installed empty even after retry - the Workshop download may be missing its content.") -ForegroundColor Yellow
    }
  }
  # Generic dependency check: read require= from installed mod.info, install/resolve missing dependencies
  foreach ($instFolder in $finalNames) {
    $instMi = Join-Path (Join-Path $ModsDir $instFolder) 'mod.info'
    if (-not (Test-Path $instMi)) { $instMi = Join-Path (Join-Path (Join-Path $ModsDir $instFolder) $GameBuild) 'mod.info' }
    if (Test-Path $instMi) {
      $instRaw = ''
      try { $instRaw = Get-Content $instMi -Raw -ErrorAction Stop } catch { }
      $reqM = [regex]::Match($instRaw, '(?m)^\s*require\s*=\s*(.+?)\s*$')
      if ($reqM.Success) {
        $reqIds = @($reqM.Groups[1].Value -split '[,;]' | ForEach-Object { $_.Trim().TrimStart('\') } | Where-Object { $_ -ne '' })
        $fAllOk = $true
        foreach ($rid in $reqIds) {
          if (Test-Path (Join-Path $ModsDir $rid)) { continue }
          $foundDep = (Get-DiskModIdMap).ContainsKey($rid)
          if ($foundDep) { continue }
          $fAllOk = $false
          if ($ModIdToWorkshop.ContainsKey($rid) -and $script:DepDepth -lt 3) {
            $depWid2 = $ModIdToWorkshop[$rid]
            Write-Host ("  Missing dependency: installing " + $rid + " (required by " + $Name + ")") -ForegroundColor Cyan
            $script:DepDepth++
            Install-Mod $depWid2 $rid | Out-Null
            Add-ModToActiveListIfMissing $depWid2
            $script:DepDepth--
            if ($script:AbortVariantBatch) { return $false }
          } else {
            Write-Host ("  WARNING: " + $Name + " requires '" + $rid + "' which is not installed and not in the known list. Install it manually via [4] if you know its Workshop ID.") -ForegroundColor Yellow
          }
        }
        if ($fAllOk -and $reqIds.Count -gt 0) { Write-Host ("  Dependencies OK: " + ($reqIds -join ', ') + " (required by " + $Name + ")") -ForegroundColor DarkGray }
      }
    }
  }
  $stamp = Get-ContentStamp $src
  $map = Get-InstallMap
  if (-not $map) { $map = New-Object PSObject }
  $entry = New-Object PSObject
  $entry | Add-Member -NotePropertyName 'installed' -NotePropertyValue $true
  $entry | Add-Member -NotePropertyName 'folders' -NotePropertyValue @($finalNames)
  $entry | Add-Member -NotePropertyName 'stamp' -NotePropertyValue $stamp
  $entry | Add-Member -NotePropertyName 'installed_on' -NotePropertyValue (Get-Date -Format 'yyyy-MM-dd')
  $entry | Add-Member -NotePropertyName 'size' -NotePropertyValue (Get-ModDiskSize @($finalNames))
  if ($carryVariants) { $entry | Add-Member -NotePropertyName 'variants' -NotePropertyValue @($carryVariants) }
  $map | Add-Member -NotePropertyName $WorkshopId -NotePropertyValue $entry -Force
  Save-InstallMap $map
  if (Test-NeedsZombieBuddyAgent $WorkshopId) {
    # ZombieBuddy (or a mod depending on it, e.g. Viewpoint): copy the native agent files to the game folder (asks for game folder once, then saves it)
    Install-ZombieBuddyAgent -AllowPrompt:$true
  }
  # Install-time B42 structure repair: a fresh install must be game-readable immediately,
  # not wait for the next manager startup. Fixes flattened versioned mods (root mod.info
  # + common/, no 42/) such as model packs - PZ B42 will not list them otherwise.
  Repair-FlattenedMods
  return $true
}

function Complete-DeferredInstall($pending, $decision) {
  # Complete a deferred install after the consolidated picker decided
  # it. $decision = @{ KeptIndices = @(int); KeptIds = @(string) }.
  # Empty KeptIndices = the user unticked all versions -> skip it.
  # Returns $true (installed) / $false (skipped or failed).
  if (@($decision.KeptIndices).Count -eq 0) {
    Write-Host (\"  Skipped: \" + [string]$pending.Name + \" (no versions selected)\") -ForegroundColor DarkGray
    return $false
  }
  $keepSet = @{}
  foreach ($ki in @($decision.KeptIndices)) { $keepSet[[int]$ki] = $true }
  $keptDirs = @(); $pickerDropped = @()
  for ($vi = 0; $vi -lt @($pending.VariantDirs).Count; $vi++) {
    if ($keepSet.ContainsKey($vi)) { $keptDirs += $pending.VariantDirs[$vi] }
    else {
      $mid = Get-ModInfoId (Join-Path $pending.VariantDirs[$vi].FullName 'mod.info')
      if ($mid -ne '') { $pickerDropped += $mid }
    }
  }
  $droppedIds = @(@($pending.VersionDroppedIds) + @($pickerDropped))
  return (Complete-InstallModCore [string]$pending.WorkshopId [string]$pending.Name $keptDirs @($decision.KeptIds) $droppedIds $pending.Prop0 [string]$pending.Src)
}

function Install-Mod([string]$WorkshopId, [string]$Name) {
  # An entry with no Workshop ID (bad user data) must not reach the
  # map save - Add-Member with an empty name throws and kills the GUI.
  if ($WorkshopId -notmatch '^\d+$') { return $false }
  Ensure-SteamCmd
  New-Item -ItemType Directory -Force -Path $ModsDir | Out-Null
  $stray = Join-Path $ModsDir 'mods'
  if ((Test-Path $stray) -and -not (Test-Path (Join-Path $stray 'mod.info'))) { Remove-Item $stray -Recurse -Force }
  # Skip entirely if already installed (all folders present with mod.info) - no download, no re-copy
  # Generic folder names (42, 41, common...) are treated as broken and get reinstalled with proper names
  $map0 = Get-InstallMap
  if ($map0) {
    $prop0 = $map0.PSObject.Properties[$WorkshopId]
    if ($prop0 -and $prop0.Value.installed -eq $true -and $prop0.Value.folders) {
      $allThere = $true
      $hasGeneric = $false
      foreach ($f in @($prop0.Value.folders)) {
        $fname = [string]$f
        if ($fname -match '^(?i)(\d{10}([_.].*)?|\d+(\.\d+)*(_\d+(\.\d+)*)?|common|mods?|main|default)$') { $hasGeneric = $true }
        $mi = Join-Path (Join-Path $ModsDir $fname) 'mod.info'
        if (-not (Test-Path $mi)) { $allThere = $false; break }
        # Don't skip if the installed folder is EMPTY (only mod.info + images, or missing referenced jar)
        $fd0 = Join-Path $ModsDir $fname
        $raw0 = ''
        try { $raw0 = Get-Content $mi -Raw -ErrorAction Stop } catch { }
        if ($raw0) {
          $mjar0 = [regex]::Match($raw0, '(?m)^\s*javaJarFile\s*=\s*(.+?)\s*$')
          if ($mjar0.Success -and -not (Test-Path (Join-Path $fd0 $mjar0.Groups[1].Value.Trim()))) { $allThere = $false; break }
          $df0 = @(Get-ChildItem $fd0 -File -ErrorAction SilentlyContinue)
          $ni0 = @($df0 | Where-Object { $_.Name -ne 'mod.info' -and $_.Extension -notmatch '(?i)\.(png|jpg|jpeg|gif|bmp)$' })
          $sd0 = @(Get-ChildItem $fd0 -Directory -ErrorAction SilentlyContinue)
          if ($ni0.Count -eq 0 -and $sd0.Count -eq 0) { $allThere = $false; break }
        }
      }
      # Auto-pick matching game version: drop installed variants that
      # definitely will not load on this build (e.g. B41-only variants
      # when running B42). Their folders are removed so the game menu
      # only shows the matching variant(s). If every folder is dropped,
      # fall through to a fresh install below.
      $keptFolders = @()
      $droppedFolders = @()
      foreach ($f in @($prop0.Value.folders)) {
        $miV = Join-Path (Join-Path $ModsDir ([string]$f)) 'mod.info'
        if (Test-ModVersionMatches $miV) { $keptFolders += [string]$f } else { $droppedFolders += [string]$f }
      }
      if ($droppedFolders.Count -gt 0) {
        foreach ($df in $droppedFolders) {
          $dd = Join-Path $ModsDir $df
          if (Test-Path $dd) { Remove-Item $dd -Recurse -Force -ErrorAction SilentlyContinue }
          Write-Host ("  Removed non-matching variant folder (not for build " + $GameBuildFull + "): " + $df) -ForegroundColor DarkGray
        }
        $prop0.Value.folders = @($keptFolders)
        Save-InstallMap $map0
        if ($keptFolders.Count -eq 0) { $allThere = $false }
      }
      if ($allThere -and -not $hasGeneric) {
        $seen = @($prop0.Value.folders | ForEach-Object { Join-Path $ModsDir ([string]$_) }) -join '; '
        Write-Host ("  Already installed: " + $Name) -ForegroundColor DarkGray
        Write-Host ("  Folders: " + $seen) -ForegroundColor DarkGray
        foreach ($f in @($prop0.Value.folders)) {
          $mi3 = Join-Path (Join-Path $ModsDir ([string]$f)) 'mod.info'
          $mid3 = Get-ModInfoId $mi3
          $mn3 = ''
          try {
            $mm3 = [regex]::Match((Get-Content $mi3 -Raw -ErrorAction Stop), '(?m)^\s*name\s*=\s*(.+?)\s*$')
            if ($mm3.Success) { $mn3 = $mm3.Groups[1].Value.Trim() }
          } catch { }
          $sz3 = 0
          try { $sz3 = (Get-Item $mi3 -ErrorAction Stop).Length } catch { }
          Write-Host ("  -> id=" + $mid3 + " name=" + $mn3 + " mod.info=" + $sz3 + " bytes") -ForegroundColor DarkGray
          try {
            # Light encoding check only (mod.info is small). The old code
            # dumped every mod.info's full content + a recursive file count
            # per already-installed mod - pure cost on the UI thread.
            $rawBytes = [IO.File]::ReadAllBytes($mi3)
            $utf8Valid = $true
            try {
              $dec = [Text.Encoding]::UTF8.GetString($rawBytes)
              $reenc = [Text.Encoding]::UTF8.GetBytes($dec)
              if ($reenc.Length -ne $rawBytes.Length) { $utf8Valid = $false }
            } catch { $utf8Valid = $false }
            if (-not $utf8Valid) { Write-Host "     mod.info encoding: INVALID - game may skip this mod!" -ForegroundColor Red }
          } catch { }
        }
        # Already installed - still check dependencies (skip path used to return before require= check)
        foreach ($sf in @($prop0.Value.folders)) {
          $sMi = Join-Path (Join-Path $ModsDir ([string]$sf)) 'mod.info'
          if (-not (Test-Path $sMi)) { $sMi = Join-Path (Join-Path (Join-Path $ModsDir ([string]$sf)) $GameBuild) 'mod.info' }
          if (Test-Path $sMi) {
            $sRaw = ''
            try { $sRaw = Get-Content $sMi -Raw -ErrorAction Stop } catch { }
            $sReq = [regex]::Match($sRaw, '(?m)^\s*require\s*=\s*(.+?)\s*$')
            if ($sReq.Success) {
              $sReqIds = @($sReq.Groups[1].Value -split '[,;]' | ForEach-Object { $_.Trim().TrimStart('\') } | Where-Object { $_ -ne '' })
              $sAllOk = $true
              foreach ($srid in $sReqIds) {
                if (Test-Path (Join-Path $ModsDir $srid)) { continue }
                $sFound = (Get-DiskModIdMap).ContainsKey($srid)
                if ($sFound) { continue }
                $sAllOk = $false
                if ($ModIdToWorkshop.ContainsKey($srid) -and $script:DepDepth -lt 3) {
                  $sDepWid = $ModIdToWorkshop[$srid]
                  Write-Host ("  Missing dependency: installing " + $srid + " (required by " + $Name + ")") -ForegroundColor Cyan
                  $script:DepDepth++
                  Install-Mod $sDepWid $srid | Out-Null
                Add-ModToActiveListIfMissing $sDepWid
                  $script:DepDepth--
                  if ($script:AbortVariantBatch) { return $false }
                } else {
                  Write-Host ("  WARNING: " + $Name + " requires '" + $srid + "' which is not installed and not in the known list. Install it manually via [4] if you know its Workshop ID.") -ForegroundColor Yellow
                }
              }
              if ($sAllOk -and $sReqIds.Count -gt 0) { Write-Host ("  Dependencies OK: " + ($sReqIds -join ', ') + " (required by " + $Name + ")") -ForegroundColor DarkGray }
            }
          }
        }
        if (Test-NeedsZombieBuddyAgent $WorkshopId) {
          # ZombieBuddy already installed - still ensure the agent files are in the game folder
          Install-ZombieBuddyAgent -AllowPrompt:$true
        }
        return $true
      }
      if ($hasGeneric) {
        Write-Host "  Fixing generic folder name(s) - reinstalling..." -ForegroundColor Yellow
        foreach ($f in @($prop0.Value.folders)) {
          $old = Join-Path $ModsDir ([string]$f)
          if (Test-Path $old) { Remove-Item $old -Recurse -Force }
        }
      }
    }
  }
  # Install prerequisites first (depth-guarded against cycles)
  if ($script:DepDepth -lt 3 -and $DepMap.ContainsKey($WorkshopId)) {
    foreach ($depWid in $DepMap[$WorkshopId]) {
      $depEntry = @($Mods | Where-Object { $_.WorkshopId -eq $depWid })
      $depName = if ($depEntry.Count -gt 0) { $depEntry[0].Name } else { "workshop item $depWid" }
      $depMap0 = Get-InstallMap
      $depDone = $false
      if ($depMap0 -and $depMap0.PSObject.Properties[$depWid]) {
        $de0 = $depMap0.PSObject.Properties[$depWid].Value
        if ($de0.installed -eq $true -and $de0.folders) {
          $depDone = $true
          foreach ($dff in @($de0.folders)) { if (-not (Test-Path (Join-Path (Join-Path $ModsDir ([string]$dff)) 'mod.info'))) { $depDone = $false; break } }
        }
      }
      if (-not $depDone) {
        Write-Host ("  Prerequisite: installing " + $depName + " (required by " + $Name + ")") -ForegroundColor Cyan
        $script:DepDepth++
        Install-Mod $depWid $depName | Out-Null
        $script:DepDepth--
        if ($script:AbortVariantBatch) { return $false }
      }
    }
  }
  $tmp = Join-Path ([IO.Path]::GetTempPath()) "pzmod_$WorkshopId"
  if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
  $src = Join-Path (Join-Path (Join-Path $SteamCmdDir 'steamapps') 'workshop') "content\$AppId\$WorkshopId"
  # If map says installed but folder is gone (user deleted it), the cache may be stale/corrupt - clear it for a fresh download
  $mapCheck = Get-InstallMap
  if ($mapCheck) {
    $propCheck = $mapCheck.PSObject.Properties[$WorkshopId]
    if ($propCheck -and $propCheck.Value.installed -eq $true -and $propCheck.Value.folders) {
      $anyMissing = $false
      foreach ($f in @($propCheck.Value.folders)) {
        if (-not (Test-Path (Join-Path $ModsDir ([string]$f)))) { $anyMissing = $true; break }
      }
      if ($anyMissing -and (Test-Path $src)) {
        Write-Host "  Clearing stale cache for fresh download..." -ForegroundColor Yellow
        Remove-Item $src -Recurse -Force -ErrorAction SilentlyContinue
      }
    }
  }
  $modsFound = @()
  if (Test-Path $src) { $modsFound = @(Get-ChildItem $src -Directory -Recurse | Where-Object { Test-Path (Join-Path $_.FullName 'mod.info') }) }
  if ($modsFound.Count -eq 0) {
    # Download with 1 retry - SteamCMD anonymous sometimes returns empty on first try
    for ($attempt = 1; $attempt -le 2; $attempt++) {
      Write-Host ("  Downloading [" + $Name + "] (attempt " + $attempt + "/2)...") -ForegroundColor DarkCyan
      $scOut = Invoke-SteamCmd @('+login', 'anonymous', '+workshop_download_item', $AppId, $WorkshopId, 'validate', '+quit')
      if (Test-Path $src) { $modsFound = @(Get-ChildItem $src -Directory -Recurse | Where-Object { Test-Path (Join-Path $_.FullName 'mod.info') }) }
      if ($modsFound.Count -gt 0) { break }
      # Still empty after this attempt - on final attempt show SteamCMD errors for diagnosis
      if ($attempt -eq 2) {
        Write-Host '  --- SteamCMD output (for diagnosis) ---' -ForegroundColor DarkGray
        @($scOut) | Where-Object { $_ -match 'ERROR|FAILED|failed|error|Timeout|timeout|Unable|denied|Rate|rate|limit|Login|login|Invalid' } | ForEach-Object { Write-Host ('    ' + $_.ToString().Trim()) -ForegroundColor DarkGray }
        Write-Host '  --- end SteamCMD output ---' -ForegroundColor DarkGray
      }
      Write-Host "  Download came back empty, retrying..." -ForegroundColor Yellow
    }
    if ($modsFound.Count -eq 0) {
      if (-not (Test-Path $src)) { Write-Host "  FAILED: SteamCMD could not fetch $WorkshopId" -ForegroundColor Red }
      else { Write-Host ("  FAILED: SteamCMD downloaded nothing usable for " + $WorkshopId + " (workshop item may be down/removed)") -ForegroundColor Red }
      return $false
    }
  } else {
    Write-Host ("  Cached: " + $Name) -ForegroundColor DarkGray
  }
  # Completeness check: SteamCMD can report success with a truncated
  # tree (large items especially) - the folder skeleton and mod.info
  # arrive but the content does not, and every other check passes on
  # mod.info alone (this is how the 6244 models pack 'installed' as a
  # bare mod.info in Oct 2026). Compare the cache size against the
  # Workshop file size and re-validate until it matches. Best effort:
  # any API failure skips the check, it never blocks an install.
  if (Test-Path $src) {
    $expectedSize = [long]0
    try {
      $szResp = Invoke-WebRequest -Uri 'https://api.steampowered.com/ISteamRemoteStorage/GetPublishedFileDetails/v1/' -Method Post -Body ('itemcount=1&publishedfileids[0]=' + $WorkshopId) -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
      $szDetail = @(($szResp.Content | ConvertFrom-Json).response.publishedfiledetails)[0]
      if ($szDetail -and $szDetail.file_size) { $expectedSize = [long]$szDetail.file_size }
    } catch { }
    if ($expectedSize -gt 0) {
      for ($szAttempt = 1; $szAttempt -le 3; $szAttempt++) {
        $actualSize = [long]0
        $szSum = (Get-ChildItem $src -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
        if ($szSum) { $actualSize = [long]$szSum }
        if ($actualSize -ge ($expectedSize * 0.95)) { break }
        Write-Host ("  Download looks incomplete (" + $actualSize + " of " + $expectedSize + " bytes) - re-downloading (round " + $szAttempt + "/3)...") -ForegroundColor Yellow
        [void](Invoke-SteamCmd @('+login', 'anonymous', '+workshop_download_item', $AppId, $WorkshopId, 'validate', '+quit'))
      }
      $szSum2 = (Get-ChildItem $src -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
      if ($szSum2 -and [long]$szSum2 -lt ($expectedSize * 0.95)) {
        Write-Host ("  WARNING: download still incomplete after retries (" + [long]$szSum2 + " of " + $expectedSize + " bytes) - installing what is available.") -ForegroundColor Yellow
      }
      $modsFound = @(Get-ChildItem $src -Directory -Recurse | Where-Object { Test-Path (Join-Path $_.FullName 'mod.info') })
    }
  }
  if ($modsFound.Count -eq 0) { Write-Host ("  WARNING: no mod found inside " + $WorkshopId) -ForegroundColor Yellow; return $false }
  # Dedup: same mod id appearing twice (e.g. 41/ and 42/ subfolders) - keep one, prefer the 42 build
  $byId = @{}
  foreach ($m in $modsFound) {
    $mid = Get-ModInfoId (Join-Path $m.FullName 'mod.info')
    if ($mid -eq '') { $mid = ('noid_' + $m.FullName) }
    if (-not $byId.ContainsKey($mid)) { $byId[$mid] = @() }
    $byId[$mid] += $m
  }
  $deduped = @()
  foreach ($k in $byId.Keys) {
    $cands = @($byId[$k])
    if ($cands.Count -eq 1) { $deduped += $cands[0] }
    else {
      $pick = $cands[0]
      foreach ($c in $cands) { if ($c.FullName -match ('(?i)[\\/]' + $GameBuild + '(\.\d+)?([\\/]|$)')) { $pick = $c; break } }
      $deduped += $pick
      Write-Host ("  Note: multiple copies of mod id '" + $k + "' found - using " + $pick.Name) -ForegroundColor DarkGray
    }
  }
  $modsFound = $deduped
  # Beauty of zomboid (3333779609) ships dead duplicate Dense Environment variants
  # the game never loads (it uses the Dense grass mod from the 'common' folder).
  # Skip them so installs stay clean; grass 1/2 are both kept (author says pick one).
  if ($WorkshopId -eq '3333779609') {
    $filtered = @($modsFound | Where-Object { $_.FullName -notmatch '(?i)modified denses? environment' })
    if ($filtered.Count -gt 0 -and $filtered.Count -lt $modsFound.Count) {
      Write-Host ("  Skipped " + ($modsFound.Count - $filtered.Count) + " dead Beauty Dense Environment duplicate(s) the game never loads.") -ForegroundColor DarkGray
      $modsFound = $filtered
    }
    # Beauty ships 2 grass styles - pick one at install time instead of installing both
    $g1 = @($modsFound | Where-Object { $_.FullName -match '(?i)grass 1' })
    $g2 = @($modsFound | Where-Object { $_.FullName -match '(?i)grass 2' })
    if (-not $script:GuiMode -and $g1.Count -gt 0 -and $g2.Count -gt 0) {
      Write-Host ''
      Write-Host '  Beauty of zomboid ships 2 grass styles - pick one:' -ForegroundColor Cyan
      Write-Host '    [1] Grass 1' -ForegroundColor White
      Write-Host '    [2] Grass 2' -ForegroundColor White
      Write-Host '    [3] Both (decide later in the game Mods menu)' -ForegroundColor White
      $gc = Read-Host '  Choose'
      if ($gc -eq '1') { $modsFound = @($modsFound | Where-Object { $_.FullName -notmatch '(?i)grass 2' }); Write-Host '  Installing Grass 1 only.' -ForegroundColor DarkGray }
      elseif ($gc -eq '2') { $modsFound = @($modsFound | Where-Object { $_.FullName -notmatch '(?i)grass 1' }); Write-Host '  Installing Grass 2 only.' -ForegroundColor DarkGray }
    }
  }
  # Auto-pick matching game version + manual pick among same-version
  # variants (shared helper; choice persisted in the install-map entry).
  $storedVariants = $null
  if ($prop0 -and $prop0.Value.PSObject.Properties['variants']) { $storedVariants = @($prop0.Value.variants | ForEach-Object { [string]$_ }) }
  $selRes = $null
  if ($script:BatchVariantDecisions) {
    # Batch mode: defer the variant decision (no popup). The batch
    # collects every pending mod and shows ONE consolidated picker
    # after the first pass. The SteamCMD cache ($src) persists, so
    # the variant folders stay available for the complete phase.
    $selRes = Select-KeptVariants $modsFound $storedVariants $Name -DeferPicker
    if ($selRes.Deferred) {
      # Dedupe: a mod can be reached twice in one batch (selected AND
      # a dependency of another selected mod). One pending entry per
      # Workshop ID - the consolidated picker shows it once.
      $already = @($script:PendingVariantDecisions | Where-Object { [string]$_.WorkshopId -eq [string]$WorkshopId })
      if ($already.Count -eq 0) {
        $script:PendingVariantDecisions += [PSCustomObject]@{ WorkshopId = [string]$WorkshopId; Name = [string]$Name; VariantDirs = @($selRes.Folders); Candidates = @($selRes.Candidates); StoredVariants = @($selRes.StoredVariants); Prop0 = $prop0; Src = [string]$src; VersionDroppedIds = @($selRes.DroppedIds); Kind = 'Install' }
      }
      Write-Host ("  Deferred variant decision: " + $Name + " (" + @($selRes.Folders).Count + " versions)") -ForegroundColor DarkGray
      return 'deferred'
    }
  } else {
    $selRes = Select-KeptVariants $modsFound $storedVariants $Name
  }
  if ($selRes.AbortBatch) { return $false }
  $modsFound = @($selRes.Folders)
  $carryVariants = $selRes.CarryVariants
  return (Complete-InstallModCore $WorkshopId $Name $modsFound $carryVariants @($selRes.DroppedIds) $prop0 $src)
}

function Get-InstalledMods {
  if (-not (Test-Path $ModsDir)) { return @() }
  Get-ChildItem $ModsDir -Directory | Select-Object -ExpandProperty Name
}

function Get-DisplayMods {
  # Sorted view (category, then name) so each category header prints once.
  # Display + pick-by-number both use this, so indices always match.
  return @($Mods | Sort-Object { $_.Cat }, { $_.Name })
}


function Install-AllMods {
  Clear-DiskModIdMap
  $order = $script:CategoryOrder
  $list = foreach ($c in $order) { $Mods | Where-Object { $_.Cat -eq $c } }
  # Never drop a mod whose category is not in $order (a future category) - append it.
  $listed = @($list | ForEach-Object { $_.WorkshopId } | Where-Object { $_ })
  $list += @($Mods | Where-Object { $listed -notcontains [string]$_.WorkshopId })
  $total = $list.Count; $n = 0; $ok = 0
  $start = Get-Date
  Write-Host ($NL + "Installing ALL MODS (" + $total + " mods, current active list). This downloads several GB - grab a coffee.") -ForegroundColor Yellow
  foreach ($m in $list) {
    $n++
    Write-Host ($NL + "[" + $n + "/" + $total + "] " + $m.Name) -ForegroundColor Cyan
    Show-GuiInstallProgress $n $total $m.Name $start 'Installing'
    if (Install-Mod $m.WorkshopId $m.Name) { $ok++ }
  }
  Write-Host ($NL + "Done: " + $ok + "/" + $total + " installed.") -ForegroundColor Green
  Pause
}

function Get-IdPackIds {
  # Cached set of Workshop IDs claimed by curated ID packs (for the CAT:
  # pack exclusion in Expand-PackIds). Computed once, then cached: the
  # uncached version re-read the pack files on every CAT: expansion,
  # which made every Mods/Packs refresh re-read them ~10x. Invalidated
  # by Save-CustomPacks (every pack edit goes through
  # one of those, so the cache is never stale).
  if ($script:IdPackIdsCache) { return $script:IdPackIdsCache }
  $ids = @{}
  foreach ($p in @(Get-AllPacks)) {
    foreach ($packId in $p.Ids) {
      if ([string]$packId -notlike 'CAT:*') { $ids[[string]$packId] = $true }
    }
  }
  $script:IdPackIdsCache = $ids
  return $ids
}
function Expand-PackIds($pack, $catalog) {
  # Expand a pack's Ids to Workshop IDs: 'CAT:<category>' becomes every mod in
  # that category (from $catalog, or the working set when omitted, so hidden
  # mods stay out), plain IDs pass through.
  # No duplicates: a CAT: pack is a catch-all - it does NOT claim a mod
  # already owned by a curated ID pack (e.g. a KI5 car is in KI5 Vehicles
  # Pack only, not also in Vehicles Pack; a Guns Pack gun is not also in
  # Weapons Pack). So every mod belongs to exactly one pack. The exclusion
  # packs never move their mods.
  if (-not $catalog) { $catalog = $Mods }
  $out = @()
  $hasCat = $false
  foreach ($id in $pack.Ids) {
    if ([string]$id -like 'CAT:*') {
      $hasCat = $true
      $cat = [string]$id.Substring(4)
      $out += @($catalog | Where-Object { [string]$_.Cat -eq $cat } | ForEach-Object { $_.WorkshopId } | Where-Object { $_ })
    } else {
      $out += [string]$id
    }
  }
  if ($hasCat) {
    $idPackIds = Get-IdPackIds
    $ownIds = @{}
    foreach ($id in $pack.Ids) { if ([string]$id -notlike 'CAT:*') { $ownIds[[string]$id] = $true } }
    $out = @($out | Where-Object { $ownIds.ContainsKey([string]$_) -or -not $idPackIds.ContainsKey([string]$_) })
  }
  return @($out | Select-Object -Unique)
}


function Get-InstalledWorkshopIds {
  # Installed = map says installed AND at least one recorded folder really exists on disk with mod.info.
  # Map-only records (folder deleted, or [10] cleaned) must NOT count as installed.
  $map = Get-InstallMap
  $ids = @()
  if ($map) {
    foreach ($p in $map.PSObject.Properties) {
      if ([string]$p.Name -notmatch '^\d+$') { continue }
      if ($p.Value.installed -eq $true -and $p.Value.folders) {
        foreach ($f in @($p.Value.folders)) {
          if (Test-Path (Join-Path (Join-Path $ModsDir ([string]$f)) 'mod.info')) { $ids += [string]$p.Name; break }
        }
      }
    }
  }
  return $ids
}

function Remove-WorkshopId([string]$WorkshopId) {
  $map = Get-InstallMap
  $folders = @()
  if ($map) {
    $prop = $map.PSObject.Properties[$WorkshopId]
    if ($prop) { $folders = @($prop.Value.folders) }
  }
  $removed = 0
  foreach ($f in $folders) {
    $dir = Join-Path $ModsDir ([string]$f)
    if (Test-Path $dir) { Remove-Item $dir -Recurse -Force; $removed++ }
  }
  if ($map) {
    $prop = $map.PSObject.Properties[$WorkshopId]
    if ($prop) { $prop.Value.installed = $false }
    Save-InstallMap $map
  }
  if ($WorkshopId -eq '3619862853') { Remove-ZombieBuddyAgent }
  return $removed
}


function Find-ModUpdates {
  # Download the latest for every INSTALLED mod in the active list and
  # compare stamps. Returns @{ Updates = @(mods with a newer Workshop
  # version); UpToDate = N; Map = $map }. Downloads only - copies
  # nothing, so the caller can prompt before installing.


  $map = Get-InstallMap
  if (-not $map) { $map = New-Object PSObject }
  Write-Host 'Checking installed mods for updates...' -ForegroundColor Yellow
  Write-Host 'Only mods that actually changed on the Workshop will be re-copied.' -ForegroundColor DarkGray

  $installedIds = @(Get-InstalledWorkshopIds)
  $toCheck = @()
  foreach ($m in $Mods) {
    if ([string]$m.WorkshopId -notmatch '^\d+$') { continue }
    if ($installedIds -contains [string]$m.WorkshopId) { $toCheck += $m }
  }
  if ($toCheck.Count -eq 0) { Write-Host 'No mods installed.' -ForegroundColor Yellow; return $null }

  Ensure-SteamCmd
  $chunkSize = 30
  $batches = [math]::Ceiling($toCheck.Count / $chunkSize)
  for ($c = 0; $c -lt $toCheck.Count; $c += $chunkSize) {
    $chunk = @($toCheck | Select-Object -Skip $c -First $chunkSize)
    $batchNo = [math]::Floor($c / $chunkSize) + 1
    Write-Host ("  Checking batch " + $batchNo + "/" + $batches + " (" + $chunk.Count + " mods)...") -ForegroundColor DarkCyan
    Show-GuiProgress ("Checking for mod updates: batch " + $batchNo + "/" + $batches + " (" + $chunk.Count + " mods)...")
    $sargs = @('+login', 'anonymous')
    foreach ($m in $chunk) { $sargs += '+workshop_download_item'; $sargs += $AppId; $sargs += $m.WorkshopId }
    $sargs += '+quit'
    [void](Invoke-SteamCmd $sargs)
  }

  $updates = @(); $upToDate = 0
  $start = Get-Date
  $n = 0
  foreach ($m in $toCheck) {
    $n++; Show-GuiInstallProgress $n $toCheck.Count $m.Name $start 'Checking'
    $id = [string]$m.WorkshopId
    if ($id -notmatch '^\d+$') { continue }
    $src = Join-Path (Join-Path (Join-Path $SteamCmdDir 'steamapps') 'workshop') ('content\' + $AppId + '\' + $id)
    if (-not (Test-Path $src)) { continue }
    $folders = @(Get-ChildItem $src -Directory -Recurse | Where-Object { Test-Path (Join-Path $_.FullName 'mod.info') })
    if ($folders.Count -eq 0) { continue }
    $prop = $map.PSObject.Properties[$id]
    $stamp = Get-FoldersStamp $folders
    if ($prop -and $prop.Value.installed -and $prop.Value.stamp -eq $stamp) {
      $upToDate++
      continue
    }
    $updates += $m
  }
  return @{ Updates = $updates; UpToDate = $upToDate; Map = $map }
}

function Install-FoundUpdates($updates, $map) {
  Clear-DiskModIdMap
  $script:AbortVariantBatch = $false
  # Copy the newer Workshop versions for $updates (found by
  # Find-ModUpdates) into the mods folder. Mirrors Install-Mod's
  # layout handling (dedup, version/common folders, old-folder cleanup).
  # Returns the count installed.
  if (-not $map) { $map = New-Object PSObject }
  $updated = 0; $anyAgent = $false
  $start = Get-Date
  $n = 0
  foreach ($m in $updates) {
    $n++; Show-GuiInstallProgress $n $updates.Count $m.Name $start 'Updating'
    $id = [string]$m.WorkshopId
    if ($id -notmatch '^\d+$') { continue }
    $src = Join-Path (Join-Path (Join-Path $SteamCmdDir 'steamapps') 'workshop') ('content\' + $AppId + '\' + $id)
    if (-not (Test-Path $src)) { continue }
    $folders = @(Get-ChildItem $src -Directory -Recurse | Where-Object { Test-Path (Join-Path $_.FullName 'mod.info') })
    if ($folders.Count -eq 0) { continue }
    $prop = $map.PSObject.Properties[$id]
    $stamp = Get-FoldersStamp $folders
    # Dedup: same mod id appearing twice (e.g. main folder + 42.13 version build) - keep one, prefer the 42 build.
    # [7] used to copy EVERY mod.info folder raw to mods root, leaving stray version folders
    # (e.g. mods/42.13/) beside the real mod. Now it mirrors Install-Mod.
    $byId = @{}
    foreach ($mm in $folders) {
      $mid = Get-ModInfoId (Join-Path $mm.FullName 'mod.info')
      if ($mid -eq '') { $mid = ('noid_' + $mm.FullName) }
      if (-not $byId.ContainsKey($mid)) { $byId[$mid] = @() }
      $byId[$mid] += $mm
    }
    $deduped = @()
    foreach ($k in $byId.Keys) {
      $cands = @($byId[$k])
      if ($cands.Count -eq 1) { $deduped += $cands[0] }
      else {
        $pick = $cands[0]
        foreach ($c in $cands) { if ($c.FullName -match ('(?i)[\\/]' + $GameBuild + '(\.\d+)?([\\/]|$)')) { $pick = $c; break } }
        $deduped += $pick
        Write-Host ("  Note: multiple copies of mod id '" + $k + "' found - using " + $pick.Name) -ForegroundColor DarkGray
      }
    }
    $folders = $deduped
    # Auto-pick matching game version + manual pick among same-version
    # variants (shared helper with Install-Mod, so updates respect the
    # pick). Old folders are all deleted below, so DroppedIds needs no
    # separate cleanup here.
    $storedVariantsU = $null
    if ($prop -and $prop.Value.PSObject.Properties['variants']) { $storedVariantsU = @($prop.Value.variants | ForEach-Object { [string]$_ }) }
    $selResU = Select-KeptVariants $folders $storedVariantsU $m.Name
    if ($selResU.AbortBatch) { break }
    $folders = @($selResU.Folders)
    $carryVariantsU = $selResU.CarryVariants
    # Delete the old installed folders first: if the download renamed its folder,
    # the old folder would otherwise be orphaned (untracked) on disk.
    if ($prop -and $prop.Value.folders) {
      foreach ($oldF in @($prop.Value.folders)) {
        $oldFd = Join-Path $ModsDir ([string]$oldF)
        if (Test-Path $oldFd) { Remove-Item $oldFd -Recurse -Force -ErrorAction SilentlyContinue }
      }
    }
    $finalNames = @()
    $usedNames = @{}
    foreach ($f in $folders) {
      $dirName = $f.Name
      if ($dirName -match '^(?i)(\d{10}([_.].*)?|\d+(\.\d+)*(_\d+(\.\d+)*)?|common|mods?|main|default)$') {
        $mid = Get-ModInfoId (Join-Path $f.FullName 'mod.info')
        if ($mid -match '^[A-Za-z0-9_.\-]+$') { $dirName = $mid }
        else { $dirName = ($id + '_' + $f.Name) }
      }
      if ($usedNames.ContainsKey($dirName)) { $dirName = ($dirName + '_' + $f.Name) }
      $usedNames[$dirName] = $true
      $dest = Join-Path $ModsDir $dirName
      if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
      $isVerFolder = $f.Name -match '^(?i)(\d{2}(\.\d+)?)$'
      $isCommonFolder = $f.Name -match '^(?i)common$'
      if ($isVerFolder -or $isCommonFolder) {
        # Mod lives in a versioned/common subfolder: the mod root is the PARENT.
        # Copy the WHOLE parent so common/ + version folders survive intact.
        $parent = $f.Parent
        [void](Copy-Item $parent.FullName $dest -Recurse -Force)
        $rootInfo = Join-Path $dest 'mod.info'
        if (-not (Test-Path $rootInfo)) { [void](Copy-Item (Join-Path $f.FullName 'mod.info') $rootInfo -Force) }
        Write-Host ("  Updated (B" + $GameBuild + " layout, kept common/ + version folders): " + $dirName) -ForegroundColor DarkGray
      } else {
        [void](Copy-Item $f.FullName $dest -Recurse -Force)
        Write-Host ("  Updated: " + $dirName) -ForegroundColor DarkGray
      }
      $finalNames += $dirName
    }
    $e = New-Object PSObject
    $e | Add-Member -NotePropertyName 'installed' -NotePropertyValue $true
    $e | Add-Member -NotePropertyName 'folders' -NotePropertyValue @($finalNames)
    $e | Add-Member -NotePropertyName 'stamp' -NotePropertyValue $stamp
    $e | Add-Member -NotePropertyName 'installed_on' -NotePropertyValue (Get-Date -Format 'yyyy-MM-dd')
    $e | Add-Member -NotePropertyName 'size' -NotePropertyValue (Get-ModDiskSize @($finalNames))
    if ($carryVariantsU) { $e | Add-Member -NotePropertyName 'variants' -NotePropertyValue @($carryVariantsU) }
    $map | Add-Member -NotePropertyName $id -NotePropertyValue $e -Force
    if (Test-NeedsZombieBuddyAgent $id) { $anyAgent = $true }
    Write-Host ("  Updated: " + $m.Name) -ForegroundColor Green
    $updated++
  }
  # Install-Mod repairs layout + refreshes the ZombieBuddy agent per mod; [7] must do
  # the same, or updates leave stale layouts (42.20/) and stale agent files behind.
  Repair-FlattenedMods
  if ($anyAgent) { $script:AgentDone = $false; Install-ZombieBuddyAgent -AllowPrompt:$true }
  Save-InstallMap $map
  # Standard: refresh every view after updates install.
  if ($script:GuiMode) { Refresh-GuiAfterListChange }
  return $updated
}

function Show-GuiUpdatePicker($updates) {
  # Update picker: select the updates to install (all selected by default).
  # Returns the selected update objects (the original $updates entries),
  # @() if the user cancelled / selected nothing, $null if the dialog
  # couldn't be built (caller falls back to the Yes/No prompt).
  # WinForms CheckedListBox (NOT WPF): the WPF picker silently
  # returned $null in v221-v225 for reasons never established (no
  # exception, no log - the fallback swallowed it). WinForms has no
  # XAML, no bindings, no Owner/scope questions - it just works.
  $allUpdates = @()
  foreach ($u in $updates) {
    $wid = ([string]$u.WorkshopId).Trim()
    if ($wid -match '^\d+$') { $allUpdates += @{ Mod = $u; Wid = $wid } }
  }
  if ($allUpdates.Count -eq 0) { $script:PickerNoUpdates = $true; return @() }
  try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    Add-Type -AssemblyName System.Drawing -ErrorAction Stop
    $form = New-Object System.Windows.Forms.Form
    $form.Text = ('Updates available (' + $allUpdates.Count + ')')
    $form.ClientSize = New-Object System.Drawing.Size(560, 430)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.TopMost = $true
    $label = New-Object System.Windows.Forms.Label
    $label.Text = 'Select the updates to install:'
    $label.Location = New-Object System.Drawing.Point(10, 10)
    $label.AutoSize = $true
    $form.Controls.Add($label)
    $list = New-Object System.Windows.Forms.CheckedListBox
    $list.Location = New-Object System.Drawing.Point(10, 35)
    $list.Size = New-Object System.Drawing.Size(540, 340)
    $list.CheckOnClick = $true
    foreach ($e in $allUpdates) {
      $disp = [string]$e.Mod.Name
      if ($disp -eq '') { $disp = '(unnamed mod)' }
      [void]$list.Items.Add($disp + '  [' + $e.Wid + ']')
    }
    for ($i = 0; $i -lt $list.Items.Count; $i++) { $list.SetItemChecked($i, $true) }
    $form.Controls.Add($list)
    $btnSelectAll = New-Object System.Windows.Forms.Button
    $btnSelectAll.Text = 'Select all'
    $btnSelectAll.Location = New-Object System.Drawing.Point(10, 390)
    $btnSelectAll.Size = New-Object System.Drawing.Size(90, 28)
    $btnSelectAll.Add_Click({ for ($i = 0; $i -lt $list.Items.Count; $i++) { $list.SetItemChecked($i, $true) } })
    $form.Controls.Add($btnSelectAll)
    $btnClear = New-Object System.Windows.Forms.Button
    $btnClear.Text = 'Clear'
    $btnClear.Location = New-Object System.Drawing.Point(108, 390)
    $btnClear.Size = New-Object System.Drawing.Size(90, 28)
    $btnClear.Add_Click({ for ($i = 0; $i -lt $list.Items.Count; $i++) { $list.SetItemChecked($i, $false) } })
    $form.Controls.Add($btnClear)
    $result = @{ Selected = $null }
    $btnInstall = New-Object System.Windows.Forms.Button
    $btnInstall.Text = 'Install Selected'
    $btnInstall.Location = New-Object System.Drawing.Point(290, 390)
    $btnInstall.Size = New-Object System.Drawing.Size(150, 28)
    $btnInstall.Add_Click({
      $sel2 = @()
      for ($i = 0; $i -lt $list.Items.Count; $i++) { if ($list.GetItemChecked($i)) { $sel2 += $allUpdates[$i].Mod } }
      $result.Selected = $sel2
      $form.Close()
    })
    $form.Controls.Add($btnInstall)
    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = 'Cancel'
    $btnCancel.Location = New-Object System.Drawing.Point(448, 390)
    $btnCancel.Size = New-Object System.Drawing.Size(90, 28)
    $btnCancel.Add_Click({ $form.Close() })
    $form.Controls.Add($btnCancel)
    Set-DialogWindowIcon $form
    [void]$form.ShowDialog()
    # Cancel / X / Install-with-nothing all mean "cancel", NOT "picker
    # failed". Flag it: `return @()` collapses to $null for the caller,
    # and without the flag Update-All can't tell cancel from failure.
    if ($result.Selected -eq $null -or @($result.Selected).Count -eq 0) { $script:PickerCancelled = $true; return @() }
    return $result.Selected
  } catch {
    $script:PickerError = [string]$_.Exception.Message
    try {
      $errText = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + "`r`n" + $_.Exception.Message + "`r`n" + $_.ScriptStackTrace + "`r`n"
      Set-Content -Path (Join-Path $PSScriptRoot 'picker-error.txt') -Value $errText -Encoding UTF8
    } catch { }
    return $null
  }
}

function Get-DiskModsNotInList([string]$safe) {
  # Mods on disk (shallow scan) that are NOT in list $safe and have a
  # mappable Workshop ID. Returns entries with WorkshopId/Name/Cat/
  # TopFolder (TopFolder feeds the install-map entry, so an added mod
  # shows Installed). Unmappable mods are skipped - they cannot be
  # added to a list (no Workshop ID to store).
  $out = @()
  if (-not (Test-Path $ModsDir)) { return $out }
  $listData = Get-NamedListData $safe
  $inList = @{}
  if ($listData) { foreach ($e in @($listData.mods)) { $inList[[string]$e.workshopId] = $true } }
  $map = Get-InstallMap
  $folderToWid = @{}
  if ($map) {
    foreach ($pr in $map.PSObject.Properties) {
      if ([string]$pr.Name -notmatch '^\d+$') { continue }
      foreach ($f in @($pr.Value.folders)) { $folderToWid[[string]$f] = [string]$pr.Name }
    }
  }
  $catalog = @{}
  foreach ($c in (Get-FullModCatalog)) { $catalog[[string]$c.WorkshopId] = $c }
  $cachedNames = Get-WorkshopNames
  $seenId = @{}
  foreach ($mi in (Get-ShallowModInfos)) {
    $mid = Get-ModInfoId $mi.FullName
    if ($mid -eq '' -or $seenId.ContainsKey($mid)) { continue }
    $seenId[$mid] = $true
    $rel = $mi.FullName.Substring($ModsDir.Length).TrimStart('\','/')
    $top = ($rel -split '[\\/]')[0]
    $wid = ''
    if ($ModIdToWorkshop.ContainsKey($mid)) { $wid = [string]$ModIdToWorkshop[$mid] }
    if ($wid -eq '' -and $folderToWid.ContainsKey($top)) { $wid = $folderToWid[$top] }
    if ($wid -eq '' -or $wid -notmatch '^\d+$') { continue }
    if ($inList.ContainsKey($wid)) { continue }
    $nm = ''; $ct = 'Others'
    if ($catalog.ContainsKey($wid)) { $nm = [string]$catalog[$wid].Name; $ct = [string]$catalog[$wid].Cat }
    if ($nm -eq '' -and $cachedNames.ContainsKey($wid)) { $nm = [string]$cachedNames[$wid] }
    if ($nm -eq '') { $nm = Get-ModInfoName $mi.FullName }
    if ($nm -eq '') { $nm = $mid }
    $out += [PSCustomObject]@{ WorkshopId = $wid; Name = $nm; Cat = $ct; TopFolder = $top }
  }
  return $out
}

function Build-StandardGridColumns($gridView, $columns, $checkTemplate, $noGripperStyle) {
  # THE GridView-column standard (single place) for code-built tables:
  # checkbox column first (Width 28, NoGripper, CheckBox cell template),
  # middle columns at their fixed widths (resizable), LAST column
  # NoGripper (its right edge is pinned to the ListView edge and must
  # not be resizable). The caller then calls Register-LastColumnFill to
  # stretch the last column to the edge. $columns: @( @{ Header;
  # Property; Width }, ... ). XAML tables follow the same rules via
  # HeaderContainerStyle="{StaticResource NoGripperHeader}" on the
  # checkbox + last columns.
  $colCheck = New-Object System.Windows.Controls.GridViewColumn
  $colCheck.Width = 28
  $colCheck.CellTemplate = $checkTemplate
  $colCheck.HeaderContainerStyle = $noGripperStyle
  [void]$gridView.Columns.Add($colCheck)
  foreach ($col in $columns) {
    $gc = New-Object System.Windows.Controls.GridViewColumn
    $gc.Header = [string]$col.Header
    $gc.Width = [double]$col.Width
    $gc.DisplayMemberBinding = New-Object System.Windows.Data.Binding([string]$col.Property)
    [void]$gridView.Columns.Add($gc)
  }
  $gridView.Columns[$gridView.Columns.Count - 1].HeaderContainerStyle = $noGripperStyle
}

function Show-GuiWpfPicker([string]$title, [string]$instruction, $candidates, $columns, [string]$addButtonText, [switch]$ShowCancelAll) {
  # Shared WPF picker dialog (replaces the WinForms DataGridView pickers,
  # whose column sizing kept fighting the scrollbar/font scale across
  # v267-v273). Same ListView + GridView pattern as the main tabs, so
  # the columns behave exactly like the ones that already work.
  # $candidates: objects with Name, WorkshopId, Cat, Status, Details,
  #   and optional IsChecked (defaults to $true when absent).
  # $columns: @( @{ Header='Name'; Property='Name'; Width=500 }, ... )
  # $addButtonText: 'Add Selected' (ModPicker).
  # Returns @{ Selected; Failed; NoCandidates }.
  if (@($candidates).Count -eq 0) { return [PSCustomObject]@{ Selected = @(); Failed = $false; NoCandidates = $true; CancelAll = $false } }
  try {
    Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
    Add-Type -AssemblyName PresentationCore -ErrorAction Stop
    Add-Type -AssemblyName WindowsBase -ErrorAction Stop
    $rows = @()
    for ($i = 0; $i -lt $candidates.Count; $i++) {
      $c = $candidates[$i]
      $checked = $true
      if ($c.PSObject.Properties['IsChecked']) { $checked = [bool]$c.IsChecked }
      $rows += [PSCustomObject]@{ Index = $i; IsChecked = $checked; Name = [string]$c.Name; WorkshopId = [string]$c.WorkshopId; Cat = [string]$c.Cat; Status = [string]$c.Status; Details = [string]$c.Details }
    }
    [xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Picker" Width="1020" Height="640" WindowStartupLocation="CenterScreen" ResizeMode="NoResize">
  <Window.Resources>
    <Style x:Key="NoGripperHeader" TargetType="GridViewColumnHeader" BasedOn="{StaticResource {x:Type GridViewColumnHeader}}">
      <Setter Property="Cursor" Value="Arrow"/>
      <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True">
          <Setter Property="Background">
            <Setter.Value>
              <LinearGradientBrush StartPoint="0,0" EndPoint="0,1">
                <GradientStop Color="#E3F7FF" Offset="0"/>
                <GradientStop Color="#BAEAFD" Offset="1"/>
              </LinearGradientBrush>
            </Setter.Value>
          </Setter>
        </Trigger>
      </Style.Triggers>
    </Style>
  </Window.Resources>
  <Grid Margin="10">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>
    <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="0,0,0,6">
      <TextBlock Text="Search:" VerticalAlignment="Center" Margin="0,0,6,0"/>
      <TextBox x:Name="PickerSearchBox" Width="940"/>
    </StackPanel>
    <TextBlock Grid.Row="1" x:Name="PickerInstruction" Margin="0,0,0,6"/>
    <ListView ScrollViewer.HorizontalScrollBarVisibility="Disabled" Grid.Row="2" x:Name="PickerList" SelectionMode="Single">
      <ListView.View><GridView x:Name="PickerGridView" AllowsColumnReorder="False"/></ListView.View>
    </ListView>
    <Border Grid.Row="3" BorderBrush="Gray" BorderThickness="1" Margin="0,8,0,0" MaxHeight="80">
      <TextBox x:Name="PickerDetail" TextWrapping="Wrap" Margin="4" IsReadOnly="True" BorderThickness="0" Background="Transparent" VerticalScrollBarVisibility="Auto" Text="Click a row to read its full details here."/>
    </Border>
    <StackPanel Grid.Row="4" Orientation="Horizontal" Margin="0,8,0,0">
      <Button x:Name="PickerWorkshop" Content="View Mod's Page" Padding="12,4" Margin="0,0,8,0"/>
      <Button x:Name="PickerAdd" Padding="12,4" Margin="390,0,8,0"/>
      <Button x:Name="PickerCancel" Content="Cancel" Padding="12,4" Margin="0,0,8,0"/>
      <Button x:Name="PickerCancelAll" Content="Cancel All" Padding="12,4" Visibility="Collapsed"/>
    </StackPanel>
  </Grid>
</Window>
'@
    $reader = New-Object System.Xml.XmlNodeReader($xaml)
    $window = [System.Windows.Markup.XamlReader]::Load($reader)
    Add-NoGripperHandler $window
    $window.Title = $title
    $window.FindName('PickerInstruction').Text = $instruction
    $window.FindName('PickerAdd').Content = $addButtonText
    if ($script:GuiWindow) { $window.Owner = $script:GuiWindow }
    Set-DialogWindowIcon $window
    $listView = $window.FindName('PickerList')
    $gridView = $window.FindName('PickerGridView')
    # Checkbox column: DataTemplate with a CheckBox bound to IsChecked.
    # (PSCustomObject does not notify, so Select all / Clear re-set
    # ItemsSource to redraw - same pattern as the main tabs' refresh.)
    $checkTpl = [System.Windows.Markup.XamlReader]::Parse('<DataTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"><CheckBox IsChecked="{Binding IsChecked}" HorizontalAlignment="Center" VerticalAlignment="Center"/></DataTemplate>')
    Build-StandardGridColumns $gridView $columns $checkTpl $window.FindResource('NoGripperHeader')
    Register-LastColumnFill $listView
    # Standard (same as the main tabs): header Select All checkbox in
    # the checkbox column + selection-gated Add button with a count.
    $hdrCheck = New-Object System.Windows.Controls.CheckBox
    $hdrCheck.Tag = 'SelectAll'
    $hdrCheck.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $hdrCheck.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $gridView.Columns[0].Header = $hdrCheck
    $state = @{ SortProp = ''; SortDesc = $false; Query = '' }
    $refresh = {
      $shown = @($rows)
      if ($state.SortProp -ne '') {
        if ($state.SortDesc) { $shown = @($shown | Sort-Object $state.SortProp -Descending) } else { $shown = @($shown | Sort-Object $state.SortProp) }
      }
      if ($state.Query -ne '') {
        $q = $state.Query.ToLower()
        $shown = @($shown | Where-Object { ([string]$_.Name).ToLower().Contains($q) -or ([string]$_.WorkshopId).ToLower().Contains($q) -or ([string]$_.Cat).ToLower().Contains($q) -or ([string]$_.Status).ToLower().Contains($q) -or ([string]$_.Details).ToLower().Contains($q) })
      }
      $listView.ItemsSource = $shown
      # Standard: Add needs at least one checked row. View on
      # Workshop is always enabled (no row, or a variant row with
      # a non-numeric Mod ID, opens the PZ Workshop main page).
      $nChecked = @($rows | Where-Object { [bool]$_.IsChecked }).Count
      $window.FindName('PickerAdd').IsEnabled = ($nChecked -gt 0)
      $window.FindName('PickerAdd').Content = ($addButtonText + ' (' + $nChecked + ')')
      $hdrCheck.IsChecked = (@($rows).Count -gt 0 -and $nChecked -eq @($rows).Count)
      # Standard: View this mod on Workshop needs a highlighted row
      # with a numeric Workshop ID whose Name is not just the ID.
      $selRow = $listView.SelectedItem
      $window.FindName('PickerWorkshop').IsEnabled = ($null -ne $selRow -and [string]$selRow.WorkshopId -match '^\d+$' -and [string]$selRow.Name -ne '' -and [string]$selRow.Name -ne [string]$selRow.WorkshopId)

    }
    # Checkbox click: the CheckBox already toggled its own IsChecked, but
    # the binding does not push it back to the row object reliably, so
    # read the clicked CheckBox and write it to the row.
    $listView.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, [System.Windows.RoutedEventHandler]{
      param($sender, $e)
      $cb = $e.OriginalSource -as [System.Windows.Controls.CheckBox]
      if ($cb -and [string]$cb.Tag -eq 'SelectAll') {
        $allChecked = (@($rows).Count -gt 0 -and @($rows | Where-Object { [bool]$_.IsChecked }).Count -eq @($rows).Count)
        foreach ($r in $rows) { $r.IsChecked = (-not $allChecked) }
        & $refresh
      } elseif ($cb -and $cb.DataContext) { $cb.DataContext.IsChecked = [bool]$cb.IsChecked; & $refresh }
    })
    # Row click: show the selected row's full Details in the detail pane
    # below (the Details column clips long text and the tooltip
    # approach did not show it). Click a row to read it in full.
    $listView.Add_SelectionChanged({
      $sel = $listView.SelectedItem
      $txt = 'Click a row to read its full details here.'
      if ($sel) {
        if ([string]$sel.Details -ne '') { $txt = [string]$sel.Details }
        elseif ([string]$sel.Name -ne '') { $txt = [string]$sel.Name }
      }
      $window.FindName('PickerDetail').Text = $txt
      # Standard: View this mod on Workshop needs a highlighted row
      # with a numeric Workshop ID whose Name is not just the ID.
      $window.FindName('PickerWorkshop').IsEnabled = ($null -ne $sel -and [string]$sel.WorkshopId -match '^\d+$' -and [string]$sel.Name -ne '' -and [string]$sel.Name -ne [string]$sel.WorkshopId)
    })
    # Header click: 2-state sort toggle (asc <-> desc), like the tabs.
    $listView.AddHandler([System.Windows.Controls.GridViewColumnHeader]::ClickEvent, [System.Windows.RoutedEventHandler]{
      param($sender, $e)
      $hdr = $e.OriginalSource -as [System.Windows.Controls.GridViewColumnHeader]
      # Sort key = the column's binding path (GridViewColumn has no Tag).
      # The checkbox column has no binding (CellTemplate), so it is skipped.
      $bind = $null
      if ($hdr -and $hdr.Column) { $bind = $hdr.Column.DisplayMemberBinding }
      if ($bind -and $bind.Path -and $bind.Path.Path) {
        $prop = [string]$bind.Path.Path
        if ($state.SortProp -eq $prop) { $state.SortDesc = -not $state.SortDesc } else { $state.SortProp = $prop; $state.SortDesc = $false }
        & $refresh
      }
    })
    $window.FindName('PickerSearchBox').Add_TextChanged({ $state.Query = [string]$window.FindName('PickerSearchBox').Text; & $refresh })
    $result = @{ Selected = $null }
    $cancelAllBtn = $window.FindName('PickerCancelAll')
    if ($ShowCancelAll) { $cancelAllBtn.Visibility = [System.Windows.Visibility]::Visible }
    $cancelAllBtn.Add_Click({ $result.CancelAll = $true; $window.Close() })
    $window.FindName('PickerAdd').Add_Click({
      $sel = @()
      foreach ($r in $rows) { if ([bool]$r.IsChecked) { $sel += $candidates[$r.Index] } }
      $result.Selected = $sel
      $window.Close()
    })
    $window.FindName('PickerWorkshop').Add_Click({ param($sender, $e); $w = [System.Windows.Window]::GetWindow($sender); if (-not $w) { return }; $lv = $w.FindName('PickerList'); if (-not $lv) { return }; $sel = $lv.SelectedItem; if ($sel -and [string]$sel.WorkshopId -match '^\d+$' -and [string]$sel.Name -ne '' -and [string]$sel.Name -ne [string]$sel.WorkshopId) { Start-Process ('https://steamcommunity.com/sharedfiles/filedetails/?id=' + [string]$sel.WorkshopId) } })
    $window.FindName('PickerCancel').Add_Click({ $window.Close() })
    & $refresh
    [void]$window.ShowDialog()
    $cancelAll = $false
    if ($result.ContainsKey('CancelAll')) { $cancelAll = [bool]$result.CancelAll }
    if ($result.Selected -eq $null -or @($result.Selected).Count -eq 0) { return [PSCustomObject]@{ Selected = @(); Failed = $false; NoCandidates = $false; CancelAll = $cancelAll } }
    return [PSCustomObject]@{ Selected = $result.Selected; Failed = $false; NoCandidates = $false; CancelAll = $cancelAll }
  } catch {
    $script:LastPickerError = $_.Exception.Message + ' || STACK: ' + [string]$_.ScriptStackTrace
    return [PSCustomObject]@{ Selected = @(); Failed = $true; NoCandidates = $false; CancelAll = $false }
  }
}

function Show-GuiModPicker([string]$title, [string]$instruction, $candidates) {
  # Thin wrapper: the WPF picker (same ListView + GridView as the tabs).
  # Columns match the manual layout: Name 500 / Workshop ID 200 / Category 220.
  return Show-GuiWpfPicker $title $instruction $candidates @(
    @{ Header = 'Name'; Property = 'Name'; Width = 500 },
    @{ Header = 'Workshop ID'; Property = 'WorkshopId'; Width = 200 },
    @{ Header = 'Category'; Property = 'Cat'; Width = 220 }
  ) 'Add Selected'
}


function Show-GuiAddInstalledPicker([string]$safe) {
  # Add-installed picker: on-disk mods not in list $safe, via the
  # shared searchable/sortable grid.
  $candidates = @(Get-DiskModsNotInList $safe)
  return Show-GuiModPicker ('Add existing mods to this list (' + $candidates.Count + ' on disk, not in this list)') 'Select the existing mods to add to this list:' $candidates
}

function Show-GuiAddFromListPicker([string]$packName) {
  # Add-from-list picker: CURRENT LIST mods not in pack $packName,
  # via the shared searchable/sortable grid.
  $pack = @(Get-AllPacks | Where-Object { [string]$_.Name -eq $packName })[0]
  if (-not $pack) { $script:LastPickerError = 'Pack not found.'; return [PSCustomObject]@{ Selected = @(); Failed = $true; NoCandidates = $false } }
  $inPack = @{}
  foreach ($id in @($pack.Ids)) { $inPack[[string]$id] = $true }
  # Read the ACTIVE list's file directly (not $Mods): $Mods can be
  # stale (the built-in catalog, 198) instead of the current list
  # (199 incl. Gore), which made the picker count 198 not 199.
  $candidates = @()
  foreach ($m in @(Get-ListDirectMods (Get-ActiveListSafe))) {
    if (-not $inPack.ContainsKey([string]$m.WorkshopId)) {
      $candidates += [PSCustomObject]@{ Name = [string]$m.Name; WorkshopId = [string]$m.WorkshopId; Cat = [string]$m.Cat }
    }
  }
  return Show-GuiModPicker ('Add from current list to ' + $packName + ' (' + $candidates.Count + ' mods not in this pack)') 'Select the mods to add to this pack:' $candidates
}

function Update-All {
  # Check for updates (installed mods only), prompt, then install.
  $res = Find-ModUpdates
  if (-not $res) { $script:LastUpdateSummary = 'No mods installed.'; Pause; return }
  $updates = @($res.Updates)
  if ($updates.Count -eq 0) {
    Write-Host 'No new mod updates.' -ForegroundColor Green
    $script:LastUpdateSummary = 'No new mod updates.'
    Pause; return
  }
  $names = @($updates | ForEach-Object { [string]$_.Name })
  if ($script:GuiMode) {
    $script:PickerCancelled = $false
    $script:PickerNoUpdates = $false
    $picked = Show-GuiUpdatePicker $updates
    if ($picked -eq $null) {
      if ($script:PickerNoUpdates) { $script:LastUpdateSummary = 'No new mod updates.'; return }
      if ($script:PickerCancelled) { $script:LastUpdateSummary = 'Mod update cancelled.'; return }
      # Picker couldn't build - fall back to the old Yes/No prompt.
      $shown = @($names | Select-Object -First 15)
      $list = ($shown -join "`n")
      if ($names.Count -gt 15) { $list += ("`n... and " + ($names.Count - 15) + " more.") }
      $msg = ("{0} installed mod(s) have updates:`n{1}`n`nInstall them?" -f $updates.Count, $list)
      if ([string]$script:PickerError -ne '') { $msg = ('Picker failed: ' + $script:PickerError + ' (see picker-error.txt)`n`n' + $msg) }
      $r = Show-GuiMessageBox $msg 'Check for updates' ([System.Windows.MessageBoxButton]::YesNo) ([System.Windows.MessageBoxImage]::Question)
      if ($r -ne [System.Windows.MessageBoxResult]::Yes) { $script:LastUpdateSummary = 'Mod update cancelled.'; return }
    } else {
      if ($picked.Count -eq 0) { $script:LastUpdateSummary = 'Mod update cancelled.'; return }
      $updates = @($picked)
    }
  } else {
    Write-Host ('{0} installed mod(s) have updates:' -f $updates.Count) -ForegroundColor Yellow
    foreach ($nm in $names) { Write-Host ('  - ' + $nm) -ForegroundColor Gray }
    $ans = Read-Host 'Install them? (Y/N)'
    if ($ans -notmatch '^[Yy]') { Write-Host 'Cancelled.' -ForegroundColor DarkGray; $script:LastUpdateSummary = 'Mod update cancelled.'; Pause; return }
  }
  $updated = [int]@(Install-FoundUpdates $updates $res.Map)[-1]
  if ($script:AbortVariantBatch) { $script:LastUpdateSummary = 'Mod update cancelled.'; Pause; return }
  Write-Host ($NL + $updated + " updated, " + $res.UpToDate + " already up to date.") -ForegroundColor Green
  $script:LastUpdateSummary = ('{0} updated, {1} already up to date.' -f $updated, $res.UpToDate)
  Pause
}

function Pause { if ($script:GuiMode) { return }; Read-Host ($NL + "Press Enter to continue") | Out-Null }


function Find-GameFolder([bool]$AllowPrompt = $false) {
  # Saved path (game-folder.txt next to this script)
  $saveFile = Join-Path $PSScriptRoot 'game-folder.txt'
  if (Test-Path $saveFile) {
    $saved = (Get-Content $saveFile -Raw -ErrorAction SilentlyContinue).Trim()
    if ($saved -and ((Test-Path (Join-Path $saved 'projectzomboid.jar')) -or (Test-Path (Join-Path $saved 'ProjectZomboid64.bat')))) { return $saved }
  }
  # Common locations
  $cands = @(
    (Join-Path $env:ProgramFiles 'Steam\steamapps\common\ProjectZomboid'),
    (Join-Path ${env:ProgramFiles(x86)} 'Steam\steamapps\common\ProjectZomboid'),
    'C:\Games\Project Zomboid',
    'C:\Games\ProjectZomboid',
    'C:\Program Files\Project Zomboid',
    'C:\Program Files (x86)\Project Zomboid',
    'D:\Games\Project Zomboid',
    'D:\SteamLibrary\steamapps\common\ProjectZomboid',
    'C:\SteamLibrary\steamapps\common\ProjectZomboid'
  )
  foreach ($c in $cands) {
    if ($c -and ((Test-Path (Join-Path $c 'projectzomboid.jar')) -or (Test-Path (Join-Path $c 'ProjectZomboid64.bat')))) { return $c }
  }
  # Shallow search under common roots
  foreach ($root in @('C:\Games', 'D:\Games', 'C:\Program Files', 'C:\Program Files (x86)')) {
    if (-not (Test-Path $root)) { continue }
    try {
      $hit = Get-ChildItem $root -Directory -Recurse -Depth 2 -ErrorAction SilentlyContinue | Where-Object { Test-Path (Join-Path $_.FullName 'projectzomboid.jar') } | Select-Object -First 1
      if ($hit) { return $hit.FullName }
    } catch { }
  }
  if (-not $AllowPrompt) { return $null }
  $typed = Read-Host 'Enter your Project Zomboid game folder (the one with ProjectZomboid64.bat)'
  if ($typed -and (Test-Path $typed) -and ((Test-Path (Join-Path $typed 'projectzomboid.jar')) -or (Test-Path (Join-Path $typed 'ProjectZomboid64.bat')))) {
    Set-Content $saveFile $typed.Trim() -Encoding ASCII
    return $typed.Trim()
  }
  Write-Host '  That folder does not look like the game folder (no projectzomboid.jar / ProjectZomboid64.bat).' -ForegroundColor Yellow
  return $null
}

function Install-GameShortcut([string]$GameFolder) {
  # Game launcher via .bat (so the ZombieBuddy agent loads - the .exe ignores _JAVA_OPTIONS).
  # Target cmd.exe (not the .bat directly): Windows 11 hides 'Pin to Start' for shortcuts
  # pointing at .bat files, but shows it for shortcuts pointing at an .exe. cmd /c still runs the .bat.
  $startMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
  if (-not (Test-Path $startMenu)) { return }
  if (-not $GameFolder -or -not (Test-Path (Join-Path $GameFolder 'ProjectZomboid64.bat'))) { return }
  $shell = New-Object -ComObject WScript.Shell
  $lnk = Join-Path $startMenu 'Project Zomboid (ZombieBuddy).lnk'
  $sc = $shell.CreateShortcut($lnk)
  $sc.TargetPath = $env:ComSpec
  $sc.Arguments = '/c "' + (Join-Path $GameFolder 'ProjectZomboid64.bat') + '"'
  $sc.WorkingDirectory = $GameFolder
  $sc.Description = 'Project Zomboid with ZombieBuddy agent (for Viewpoint 3D)'
  $exe = Join-Path $GameFolder 'ProjectZomboid64.exe'
  if (Test-Path $exe) { $sc.IconLocation = $exe }
  $sc.Save()
  Write-Host '  Start Menu shortcut: Project Zomboid (ZombieBuddy)' -ForegroundColor Green
}

function Install-ManagerShortcut([string]$GameFolder = '') {
  # Mod manager itself (same cmd.exe wrapper so it is pinnable). Icon = the game icon.
  $startMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
  if (-not (Test-Path $startMenu)) { return }
  $mgrBat = Join-Path $PSScriptRoot 'Run-ModManager.bat'
  if (-not (Test-Path $mgrBat)) { return }
  $shell = New-Object -ComObject WScript.Shell
  $lnk2 = Join-Path $startMenu 'PZ Mod Manager.lnk'
  $sc2 = $shell.CreateShortcut($lnk2)
  $sc2.TargetPath = $env:ComSpec
  $sc2.Arguments = '/c "' + $mgrBat + '"'
  $sc2.WorkingDirectory = $PSScriptRoot
  $sc2.Description = ('PZ Mod Manager - install and manage Project Zomboid B' + $GameBuild + ' mods')
  if (-not $GameFolder) { $GameFolder = Find-GameFolder -AllowPrompt:$false }
  if ($GameFolder) {
    $exe = Join-Path $GameFolder 'ProjectZomboid64.exe'
    if (Test-Path $exe) { $sc2.IconLocation = $exe }
  }
  $sc2.Save()
  Write-Host '  Start Menu shortcut: PZ Mod Manager' -ForegroundColor Green
}

function Install-StartMenuShortcuts([string]$GameFolder) {
  Install-GameShortcut $GameFolder
  Install-ManagerShortcut $GameFolder
}

function Repair-ManagerShortcut {
  # Each release extracts to a new version-named folder (PZModManager-v91,
  # -v92, ...), so a Start Menu shortcut from an older version points at the
  # old folder. On every run, repoint the existing shortcut at THIS copy.
  # If the user deleted the shortcut, leave it deleted (don't recreate it).
  $startMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
  $lnk = Join-Path $startMenu 'PZ Mod Manager.lnk'
  if (-not (Test-Path $lnk)) { return }
  $mgrBat = Join-Path $PSScriptRoot 'Run-ModManager.bat'
  if (-not (Test-Path $mgrBat)) { return }
  try {
    $shell = New-Object -ComObject WScript.Shell
    $sc = $shell.CreateShortcut($lnk)
    $wantArgs = '/c "' + $mgrBat + '"'
    $needsSave = ($sc.Arguments -ne $wantArgs -or $sc.WorkingDirectory -ne $PSScriptRoot -or $sc.TargetPath -ne $env:ComSpec)
    # Game icon for the shortcut (existing shortcuts predate it). IconLocation is
    # stored with a ',0' index suffix, so accept both forms when comparing.
    $game = Find-GameFolder -AllowPrompt:$false
    $gameExe = $null
    if ($game) {
      $ge = Join-Path $game 'ProjectZomboid64.exe'
      if (Test-Path $ge) { $gameExe = $ge }
    }
    if ($gameExe -and $sc.IconLocation -ne $gameExe -and $sc.IconLocation -ne ($gameExe + ',0')) {
      $sc.IconLocation = $gameExe
      $needsSave = $true
    }
    if ($needsSave) {
      $sc.TargetPath = $env:ComSpec
      $sc.Arguments = $wantArgs
      $sc.WorkingDirectory = $PSScriptRoot
      $sc.Description = ('PZ Mod Manager - install and manage Project Zomboid B' + $GameBuild + ' mods')
      $sc.Save()
      Write-Host '  Start Menu shortcut updated to this folder.' -ForegroundColor DarkGray
    }
  } catch { }
}

function Test-NeedsZombieBuddyAgent([string]$WorkshopId) {
  # True if this mod IS ZombieBuddy or depends on it (DepMap). Installing such a mod
  # must ensure the agent + shortcuts, even when ZombieBuddy itself was already installed
  # (its DepMap prerequisite check would otherwise skip it entirely).
  if ($WorkshopId -eq '3619862853') { return $true }
  if ($DepMap.ContainsKey($WorkshopId) -and (@($DepMap[$WorkshopId]) -contains '3619862853')) { return $true }
  return $false
}

function Remove-ZombieBuddyAgent {
  # Called when ZombieBuddy is uninstalled: remove the agent files, the game shortcut,
  # and the -agentlib line from the launcher. Leaving the DLL out but keeping -agentlib
  # would stop the game from starting, so the launcher line must go too.
  # The 'PZ Mod Manager' shortcut stays - it is the manager's own shortcut, not tied to any mod.
  # -Xmx stays (helps all mods, not just ZombieBuddy).
  $game = Find-GameFolder -AllowPrompt:$false
  if (-not $game) { return }
  foreach ($fn in @('ZombieBuddy.jar', 'zbNative.dll')) {
    $fp = Join-Path $game $fn
    if (Test-Path $fp) { Remove-Item $fp -Force; Write-Host ('  Removed agent file: ' + $fn) -ForegroundColor DarkGray }
  }
  $startMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
  $lnk = Join-Path $startMenu 'Project Zomboid (ZombieBuddy).lnk'
  if (Test-Path $lnk) { Remove-Item $lnk -Force; Write-Host '  Removed Start Menu shortcut: Project Zomboid (ZombieBuddy)' -ForegroundColor DarkGray }
  $bat = Join-Path $game 'ProjectZomboid64.bat'
  $bak = $bat + '.bak'
  if (Test-Path $bat) {
    $bakJava = $null
    if (Test-Path $bak) {
      foreach ($bl in @(Get-Content $bak -ErrorAction SilentlyContinue)) {
        if ($bl -match '^\s*SET\s+_JAVA_OPTIONS\s*=(.*)$') { $bakJava = $bl; break }
      }
    }
    $restore = $null
    if ($bakJava -and $bakJava -notmatch 'ZombieBuddy|zbNative') { $restore = $bakJava }
    $lines = @(Get-Content $bat -ErrorAction SilentlyContinue)
    $out = @()
    $changed = $false
    foreach ($ln in $lines) {
      if ($ln -match '^\s*SET\s+_JAVA_OPTIONS\s*=' -and $ln -match 'agentlib:zbNative') {
        $changed = $true
        if ($restore) { $out += $restore; $restore = $null }
        # else: drop the agent line entirely
      } else {
        $out += $ln
      }
    }
    if ($changed) {
      Set-Content $bat $out -Encoding ASCII
      Write-Host '  Removed -agentlib:zbNative from ProjectZomboid64.bat (game starts without the agent).' -ForegroundColor DarkGray
    }
  }
  $script:AgentDone = $false
}

function Install-ZombieBuddyAgent([bool]$AllowPrompt = $false) {
  if ($script:AgentDone) { return }
  # Find ZombieBuddy mod folder
  $zbDir = Join-Path $ModsDir 'ZombieBuddy'
  if (-not (Test-Path $zbDir)) {
    $found = @(Get-ChildItem $ModsDir -Recurse -Filter 'mod.info' -File -ErrorAction SilentlyContinue | Where-Object { (Get-ModInfoId $_.FullName) -eq 'ZombieBuddy' } | Select-Object -First 1)
    if ($found) { $zbDir = $found.DirectoryName }
  }
  if (-not (Test-Path $zbDir)) { Write-Host '  ZombieBuddy mod is not installed yet. Install it first (Living Worlds Pack or [3]).' -ForegroundColor Yellow; return }
  $jar = Get-ChildItem $zbDir -Recurse -Filter 'ZombieBuddy.jar' -File -ErrorAction SilentlyContinue | Select-Object -First 1
  $dll = Get-ChildItem $zbDir -Recurse -Filter 'zbNative.dll' -File -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $jar) { Write-Host '  ZombieBuddy.jar not found inside the ZombieBuddy mod folder.' -ForegroundColor Yellow; return }
  $game = Find-GameFolder -AllowPrompt:$AllowPrompt
  if (-not $game) { if ($AllowPrompt) { Write-Host '  Game folder not found. Enter it when asked.' -ForegroundColor Yellow }; return }
  Copy-Item $jar.FullName (Join-Path $game 'ZombieBuddy.jar') -Force
  Write-Host ('  Copied ZombieBuddy.jar -> ' + $game) -ForegroundColor Green
  if ($dll) {
    Copy-Item $dll.FullName (Join-Path $game 'zbNative.dll') -Force
    Write-Host ('  Copied zbNative.dll -> ' + $game) -ForegroundColor Green
  } else {
    Write-Host '  zbNative.dll not found in mod folder - only the JAR was copied.' -ForegroundColor Yellow
  }
  # Patch ProjectZomboid64.bat: -agentlib:zbNative (what the mod's own install prompt asks for) + raise RAM to 8GB if lower
  $bat = Join-Path $game 'ProjectZomboid64.bat'
  if (Test-Path $bat) {
    $lines = @(Get-Content $bat -ErrorAction SilentlyContinue)
    $hasAgentLib = @($lines | Where-Object { $_ -match 'agentlib:zbNative' }).Count -gt 0
    $needsRam = $false
    foreach ($ln in $lines) {
      $mm = [regex]::Match($ln, '-Xmx(\d+)([mMgG])')
      if ($mm.Success) {
        $mb = [int]$mm.Groups[1].Value
        if ($mm.Groups[2].Value -match '[gG]') { $mb = $mb * 1024 }
        if ($mb -lt 8192) { $needsRam = $true; break }
      }
    }
    if ((-not $hasAgentLib) -or $needsRam) {
      Copy-Item $bat ($bat + '.bak') -Force
      $out = @()
      $patched = $false
      foreach ($ln in $lines) {
        $newLn = $ln
        if (-not $patched -and $newLn -match '^\s*SET\s+_JAVA_OPTIONS\s*=') {
          $newLn = 'SET _JAVA_OPTIONS=-agentlib:zbNative'
          $patched = $true
        }
        $mm2 = [regex]::Match($newLn, '-Xmx(\d+)([mMgG])')
        if ($mm2.Success) {
          $mb2 = [int]$mm2.Groups[1].Value
          if ($mm2.Groups[2].Value -match '[gG]') { $mb2 = $mb2 * 1024 }
          if ($mb2 -lt 8192) { $newLn = $newLn -replace '-Xmx\d+[mMgG]', '-Xmx8192m' }
        }
        $out += $newLn
      }
      if (-not $patched -and -not $hasAgentLib) { $out = @('SET _JAVA_OPTIONS=-agentlib:zbNative') + $out }
      Set-Content $bat $out -Encoding ASCII
      if (-not $hasAgentLib) { Write-Host '  Patched ProjectZomboid64.bat: _JAVA_OPTIONS=-agentlib:zbNative (backup: ProjectZomboid64.bat.bak)' -ForegroundColor Green }
      if ($needsRam) { Write-Host '  Raised RAM in ProjectZomboid64.bat: -Xmx8192m (8GB)' -ForegroundColor Green }
    } else {
      Write-Host '  ProjectZomboid64.bat already uses -agentlib:zbNative and 8GB+ RAM.' -ForegroundColor DarkGray
    }
  } else {
    Write-Host '  No ProjectZomboid64.bat in game folder - launch options not patched.' -ForegroundColor Yellow
  }
  Install-StartMenuShortcuts $game
  $script:AgentDone = $true
  Write-Host '  Launch the game from the Start Menu shortcut or ProjectZomboid64.bat (not the .exe).' -ForegroundColor Cyan
}


# ---------------- GUI (WPF) — Phase 1: Mods screen ----------------
# Text menu stays for everything else. Launch: [11] in the menu, or PZModManager.ps1 -Gui.
# The window freezes briefly during installs (engine runs on the UI thread); progress shows in the console.


function Refresh-GuiCategories {
  if (-not $script:GuiCategoryBox) { return }
  $script:GuiCategoryBox.Items.Clear()
  [void]$script:GuiCategoryBox.Items.Add('All categories')
  [void]$script:GuiCategoryBox.Items.Add('Installed')
  [void]$script:GuiCategoryBox.Items.Add('Not Installed')
  foreach ($c in @($Mods | ForEach-Object { $_.Cat } | Where-Object { $_ } | Sort-Object -Unique)) {
    [void]$script:GuiCategoryBox.Items.Add($c)
  }
  $script:GuiCategoryBox.SelectedIndex = 0
  $script:GuiCategory = 'All categories'
  if ($script:GuiPackFilterBox) {
    $script:GuiPackFilterBox.Items.Clear()
    [void]$script:GuiPackFilterBox.Items.Add('All packs')
    foreach ($pk in @(Get-AllPacks | Sort-Object Name)) { [void]$script:GuiPackFilterBox.Items.Add([string]$pk.Name) }
    $script:GuiPackFilterBox.SelectedIndex = 0
    $script:GuiPackFilter = 'All packs'
  }
}

function Get-AllCategoryNames {
  # Every known category: current list + full catalog + the built-in
  # CategoryOrder + saved overrides + user-created category names.
  $names = @()
  $names += @($Mods | ForEach-Object { $_.Cat })
  $names += @(Get-FullModCatalog | ForEach-Object { $_.Cat })
  $names += $script:CategoryOrder
  $names += @((Get-CustomCategories).Values)
  $names += @(Get-CustomCategoryNames)
  # Trim: a stored " Graphics " (leading/trailing space) survives
  # Sort-Object -Unique as a phantom row - sorts first (space < A),
  # matches 0 mods, and becomes the detail fallback. Trimming collapses
  # it onto the clean name.
  return @($names | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ -ne '' } | Sort-Object -Unique)
}

function Get-CustomCategoryNames {
  # Extra (empty) category names for the ACTIVE list, stored in that
  # list's file (categories:[]). Without them, an empty category would
  # vanish on restart (no mod carries its name, not in CategoryOrder).
  $safe = Get-ActiveListSafe
  if ($safe -eq '') { return @() }
  $d = Get-NamedListData $safe
  if (-not $d) { return @() }
  return @(@($d.categories) | ForEach-Object { [string]$_ } | Where-Object { $_ -ne '' })
}

function Add-CustomCategoryName([string]$name) {
  $safe = Get-ActiveListSafe
  if ($safe -eq '') { return }
  $d = Get-NamedListData $safe
  if (-not $d) { return }
  $names = @(@($d.categories) | ForEach-Object { [string]$_ })
  if ($names -notcontains $name) { $names += $name }
  Save-NamedListData $safe ([string]$d.name) @($d.mods) $null $names
}

function Remove-CustomCategoryName([string]$name) {
  $safe = Get-ActiveListSafe
  if ($safe -eq '') { return }
  $d = Get-NamedListData $safe
  if (-not $d) { return }
  $names = @((@($d.categories) | ForEach-Object { [string]$_ }) | Where-Object { $_ -ne $name })
  Save-NamedListData $safe ([string]$d.name) @($d.mods) $null $names
}

function Add-GuiCategory {
  # Add a category by name (Categories tab), via a prompt box. It
  # starts empty; assigning mods to it happens via the Mods tab
  # row dropdowns.
  $name = Read-GuiInput 'New category name' 'PZ Mod Manager' ''
  if (-not $name) { return }
  $name = $name.Trim()
  if ($name -eq '') { return }
  $all = @(Get-AllCategoryNames)
  $existing = @($all | Where-Object { $_ -eq $name })
  if ($existing) { Set-GuiTransientStatus (("Category '" + $existing[0] + "' already exists.")); return }
  Add-CustomCategoryName $name
  Set-GuiTransientStatus (("Added category '" + $name + "'."))
  # Standard: refresh every view after this change (one composite call).
  Refresh-GuiAfterListChange
}


function Cycle-GuiCategoriesSort([string]$col) {
  # Click a Categories header: toggle ascending <-> descending. Never clears.
  if ($script:GuiCategoriesSortColumn -eq $col) {
    $script:GuiCategoriesSortDescending = -not $script:GuiCategoriesSortDescending
  } else { $script:GuiCategoriesSortColumn = $col; $script:GuiCategoriesSortDescending = $false }
  Refresh-GuiCategoriesTab
}
function Update-GuiCategorySelectionButtons {
  # Standard: selection-requiring buttons disabled until the
  # requirement is met. Delete needs a checked category.
  $nc = 0
  if ($script:GuiSelectedCategories) { $nc = $script:GuiSelectedCategories.Count }
  if ($script:GuiCategoryRenameDeleteButton) { $script:GuiCategoryRenameDeleteButton.IsEnabled = ($nc -gt 0) }
  Sync-GuiHeaderCheckbox $script:GuiCategoryListView 'SelectAllCategories' $script:GuiCategoriesShownNames $script:GuiSelectedCategories
}

function Refresh-GuiCategoriesTab {
  # Categories tab mirrors the Packs tab: a category list on top, the
  # selected category's mods below. Select categories to delete them in
  # bulk; tick mods and use Move selected to move them.
  if (-not $script:GuiCategoryListView) { return }
  if ($script:GuiRefreshingCategoriesTab) { return }
  $script:GuiRefreshingCategoriesTab = $true
  try {
    # Self-heal: $Mods must be the ACTIVE list's mods. A failed
    # activation clears $Mods to @() and returns early, leaving the
    # tabs showing 0 even though the active list has mods. Reload
    # from the active list so this tab always shows its contents.
    $act0 = Get-ActiveListSafe
    if ($act0 -ne '') { [void](Set-ModsFromNamedList $act0) }
    if (-not $script:GuiSelectedMods) { $script:GuiSelectedMods = @{} }
    if (-not $script:GuiSelectedCategories) { $script:GuiSelectedCategories = @{} }
    if ($script:GuiModMoveCategoryBox) { $script:GuiModMoveCategoryBox.Items.Clear(); foreach ($cc in @(Get-AllCategoryNames)) { [void]$script:GuiModMoveCategoryBox.Items.Add($cc) } }
    $installed = @(Get-InstalledWorkshopIds)
    $allNames = @(Get-AllCategoryNames)
    $script:GuiCategoriesTotal = $allNames.Count
    $script:GuiCategoriesTotalMods = $Mods.Count
    # Only list categories that have mods in the active list, plus
    # user-created (empty) categories from this list. The built-in
    # catalog/CategoryOrder categories with 0 mods in this list are
    # hidden - otherwise an empty list shows 20 empty categories.
    # (The Move dropdown still lists every category, so mods can be
    # moved into an empty built-in category.)
    $customNames = @(Get-CustomCategoryNames)
    $rows = @()
    foreach ($cat in $allNames) {
      $catMods = @($Mods | Where-Object { [string]$_.Cat -eq $cat })
      if ($catMods.Count -eq 0 -and $customNames -notcontains [string]$cat) { continue }
      $instCount = 0
      foreach ($m in $catMods) { if ($installed -contains [string]$m.WorkshopId) { $instCount++ } }
      $rows += [PSCustomObject]@{
        Name = [string]$cat
        Mods = $catMods.Count
        Installed = ($instCount.ToString() + '/' + $catMods.Count.ToString())
        InstalledCount = $instCount
        IsChecked = $script:GuiSelectedCategories.ContainsKey([string]$cat)
      }
    }
    # Drop stale category-selection keys (a selected category that
    # became empty and is now hidden): the count must match what's
    # actually selected. Prune against the listed set (pre-search), so a
    # search never wipes a selection.
    $listedCats = @($rows | ForEach-Object { [string]$_.Name })
    foreach ($k in @($script:GuiSelectedCategories.Keys)) { if ($listedCats -notcontains $k) { $script:GuiSelectedCategories.Remove($k) } }
    $search = ''
    if ($script:GuiCategorySearch) { $search = ([string]$script:GuiCategorySearch).Trim().ToLower() }
    if ($search -ne '') { $rows = @($rows | Where-Object { ([string]$_.Name).ToLower() -like ('*' + $search + '*') }) }
    $col = $script:GuiCategoriesSortColumn
    if ($col -eq 'Mods') { if ($script:GuiCategoriesSortDescending) { $rows = @($rows | Sort-Object Mods, Name -Descending) } else { $rows = @($rows | Sort-Object Mods, Name) } }
    elseif ($col -eq 'Installed') { if ($script:GuiCategoriesSortDescending) { $rows = @($rows | Sort-Object InstalledCount, Name -Descending) } else { $rows = @($rows | Sort-Object InstalledCount, Name) } }
    elseif ($col -eq 'Name') { if ($script:GuiCategoriesSortDescending) { $rows = @($rows | Sort-Object Name -Descending) } else { $rows = @($rows | Sort-Object Name) } }
    else { $rows = @($rows | Sort-Object Name) }
    $script:GuiCategoryListView.ItemsSource = $rows
    $script:GuiCategoriesShown = $rows.Count
    $script:GuiCategoriesShownNames = @{}
    foreach ($r in $rows) { $script:GuiCategoriesShownNames[[string]$r.Name] = $true }
    # Header select-all checkbox.
    if ($script:GuiCategoryListView.View -and $script:GuiCategoryListView.View.Columns -and $script:GuiCategoryListView.View.Columns.Count -gt 0) {
      $hdrCb = $script:GuiCategoryListView.View.Columns[0].Header
      if ($hdrCb -is [System.Windows.Controls.CheckBox]) {
        $selCount = 0
        foreach ($r in $rows) { if ($r.IsChecked) { $selCount++ } }
        if ($rows.Count -eq 0 -or $selCount -eq 0) { $hdrCb.IsChecked = $false }
        elseif ($selCount -eq $rows.Count) { $hdrCb.IsChecked = $true }
        else { $hdrCb.IsChecked = $false }
      }
    }
    # Header sort indicators.
    if ($script:GuiCategoryListView.View -and $script:GuiCategoryListView.View.Columns) {
      $gvCols = $script:GuiCategoryListView.View.Columns
      $plain = @('Name', 'Installed')
      for ($i = 0; $i -lt 2 -and ($i + 1) -lt $gvCols.Count; $i++) { $gvCols[$i + 1].Header = $plain[$i] }
      if ($col -eq 'Name') { $gvCols[1].Header = if ($script:GuiCategoriesSortDescending) { 'Name (Z-A)' } else { 'Name (A-Z)' } }
      elseif ($col -eq 'Installed') { $gvCols[2].Header = if ($script:GuiCategoriesSortDescending) { 'Installed (9-0)' } else { 'Installed (0-9)' } }
    }
    # Detail: keep the selected category, or fall back to the first
    # SHOWN one (a hidden empty category must not become the detail).
    $detailName = [string]$script:GuiCategoryDetailName
    $shownNames = @($rows | ForEach-Object { [string]$_.Name })
    if ($detailName -eq '' -or -not ($shownNames -contains $detailName)) {
      if ($shownNames.Count -gt 0) { $script:GuiCategoryDetailName = [string]$shownNames[0]; $detailName = $script:GuiCategoryDetailName } else { $detailName = '' }
    }
    Update-GuiStatusBar
  } finally {
    $script:GuiRefreshingCategoriesTab = $false
  }


  Update-GuiCategorySelectionButtons
  Sync-GuiHeaderCheckbox $script:GuiCategoryListView 'SelectAllCategories' $script:GuiCategoriesShownNames $script:GuiSelectedCategories
}

function Rename-GuiCategory([string]$oldName) {
  # Rename a category in the active list: every mod in it moves to
  # the new name (same machinery as Move To Category), the list's
  # stored category names follow, and pack CAT: references follow -
  # built-in packs fed by the old name get a custom copy carrying
  # the new reference so they keep their members.
  if ($oldName -eq 'Others') { Set-GuiTransientStatus ('Others cannot be renamed (it is the fallback).'); return }
  $newName = Read-GuiInput 'New name for the category' 'PZ Mod Manager' $oldName
  if (-not $newName -or $newName -eq $oldName) { return }
  if (@(Get-AllCategoryNames) -contains $newName) { Set-GuiTransientStatus (("A category named '" + $newName + "' already exists.")); return }
  $moved = Move-CategoryMods $oldName $newName
  $customNames = @(Get-CustomCategoryNames)
  if ($customNames -contains $oldName) { Remove-CustomCategoryName $oldName; Add-CustomCategoryName $newName }
  elseif ($moved -eq 0) { Add-CustomCategoryName $newName }
  $activeList = Get-ActiveListSafe
  $customPacks = @(Get-CustomPacks)
  $packsChanged = $false
  foreach ($cp in $customPacks) {
    if ([string]$cp.List -ne $activeList) { continue }
    $newIds = @($cp.Ids | ForEach-Object { if ([string]$_ -eq ('CAT:' + $oldName)) { 'CAT:' + $newName } else { [string]$_ } })
    if (@(Compare-Object @($cp.Ids) $newIds).Count -gt 0) { $cp.Ids = $newIds; $packsChanged = $true }
  }
  foreach ($bpName in @(Get-BuiltinCatPackNames $oldName)) {
    $existing = @($customPacks | Where-Object { $_.Name -eq $bpName -and [string]$_.List -eq $activeList })[0]
    if ($existing) { continue }
    $bp = @($Packs | Where-Object { [string]$_.Name -eq $bpName })[0]
    if (-not $bp) { continue }
    $newIds = @($bp.Ids | ForEach-Object { if ([string]$_ -eq ('CAT:' + $oldName)) { 'CAT:' + $newName } else { [string]$_ } })
    $customPacks += @{ Name = $bpName; Desc = [string]$bp.Desc; Ids = $newIds; Source = $bpName; List = $activeList; Created = (Get-Date -Format 'yyyy-MM-dd') }
    $packsChanged = $true
  }
  if ($packsChanged) { Save-CustomPacks $customPacks }
  if ($script:GuiSelectedCategories -and $script:GuiSelectedCategories.ContainsKey($oldName)) {
    $script:GuiSelectedCategories.Remove($oldName)
    $script:GuiSelectedCategories[$newName] = $true
  }
  Set-GuiTransientStatus (("Renamed category '" + $oldName + "' to '" + $newName + "' (" + $moved + " mod(s) moved)."))
  Refresh-GuiAfterListChange
}

function Delete-GuiSelectedCategories {
  # Delete every selected category (main table). Each category's mods move
  # to Others. Others cannot be deleted. One confirm for the batch.
  # A deleted category that fed a built-in CAT: pack empties that pack
  # (its mods can be moved back with Move selected).
  if (-not $script:GuiSelectedCategories -or $script:GuiSelectedCategories.Count -eq 0) { Set-GuiTransientStatus ('Select some categories first.'); return }
  $cats = @($script:GuiSelectedCategories.Keys | Where-Object { $_ -ne 'Others' } | Sort-Object)
  if ($cats.Count -eq 0) { Set-GuiTransientStatus ('Others cannot be deleted (it is the fallback).'); return }
  $msg = 'Delete ' + $cats.Count + ' categor(ies) (' + ($cats -join ', ') + ')? Every mod in them moves to Others.'
  $warns = $false
  foreach ($cat in $cats) { if (@(Get-BuiltinCatPackNames $cat).Count -gt 0) { $warns = $true } }
  if ($warns) { $msg += ' A built-in pack built from one of them will be empty (its mods can be moved back with Move selected).' }
  $res = Show-GuiMessageBox $msg 'PZ Mod Manager' ([System.Windows.MessageBoxButton]::YesNo) ([System.Windows.MessageBoxImage]::Warning)
  if ($res -ne [System.Windows.MessageBoxResult]::Yes) { return }
  foreach ($cat in $cats) { [void](Move-CategoryMods $cat 'Others'); Remove-CustomCategoryName $cat }
  $script:GuiSelectedCategories = @{}
  Set-GuiTransientStatus (('Deleted ' + $cats.Count + ' categor(ies).'))
  Refresh-GuiAfterListChange
}
function Set-StoredModCategory([string]$workshopId, [string]$cat) {
  # Keep the STORED cat in every named list in sync
  # with a per-mod category change. The Lists tab renders the stored cat
  # (not the override), so without this it would keep showing the old
  # category after a per-mod edit.
  if (Test-Path $ListsDir) {
    foreach ($f in @(Get-ChildItem $ListsDir -Filter '*.json' -File -ErrorAction SilentlyContinue)) {
      try {
        $d = Get-Content $f.FullName -Raw | ConvertFrom-Json
        $dirty = $false
        foreach ($e in @($d.mods)) { if ([string]$e.workshopId -eq $workshopId) { $e.cat = $cat; $dirty = $true } }
        if ($dirty) { $d | ConvertTo-Json -Depth 3 | Set-Content $f.FullName -Encoding UTF8 }
      } catch { }
    }
  }
}

function Move-CategoryMods($oldCat, $newCat) {
  # Move every mod in $oldCat to $newCat (used by Delete category).
  # Returns the number of mods moved.
  $n = 0
  foreach ($m in @($Mods)) {
    if ([string]$m.Cat -eq $oldCat) {
      Save-CustomCategory ([string]$m.WorkshopId) $newCat
      Set-StoredModCategory ([string]$m.WorkshopId) $newCat
      $m.Cat = $newCat
      $n++
    }
  }
  foreach ($m in @($script:DefaultBase)) {
    if ([string]$m.Cat -eq $oldCat) { $m.Cat = $newCat }
  }
  return $n
}

function Get-BuiltinCatPackNames($cat) {
  # Built-in packs built from a CAT: reference to $cat.
  $out = @()
  foreach ($p in $Packs) {
    foreach ($id in @($p.Ids)) {
      if ([string]$id -eq ('CAT:' + $cat)) { $out += [string]$p.Name; break }
    }
  }
  return $out
}

function Move-GuiSelectedMods {
  # Bulk-move every checked mod to the category in the Mods tab Move box.
  # Clears the selection after the move.
  if (-not $script:GuiSelectedMods -or $script:GuiSelectedMods.Count -eq 0) { Set-GuiTransientStatus ('Select some mods first.'); return }
  $cat = ''
  if ($script:GuiModMoveCategoryBox) { $cat = ([string]$script:GuiModMoveCategoryBox.Text).Trim() }
  if ($cat -eq '') { Set-GuiTransientStatus ('Pick a category to move the selected mods to.'); return }
  $existing = @($Mods | ForEach-Object { $_.Cat } | Where-Object { $_ } | Sort-Object -Unique | Where-Object { $_ -eq $cat })
  if ($existing) { $cat = $existing[0] }
  $n = 0
  foreach ($id in @($script:GuiSelectedMods.Keys)) {
    $m = @($Mods | Where-Object { [string]$_.WorkshopId -eq [string]$id })[0]
    if (-not $m) { continue }
    if ([string]$m.Cat -eq $cat) { continue }
    Save-CustomCategory ([string]$m.WorkshopId) $cat
    Set-StoredModCategory ([string]$m.WorkshopId) $cat
    $m.Cat = $cat
    foreach ($mm in @($script:DefaultBase)) { if ([string]$mm.WorkshopId -eq [string]$m.WorkshopId) { $mm.Cat = $cat } }
    $n++
  }
  $script:GuiSelectedMods = @{}
  # Standard: refresh every view after this change (one composite call).
  Refresh-GuiAfterListChange
  Set-GuiTransientStatus (("Moved " + $n + " selected mod(s) to '" + $cat + "'."))
}


function Write-GuiErrorDump($err, [string]$where) {
  # Full error record for gui-error.txt: type, message, the exact
  # failing line, and the stack AT THE CATCH SITE (the main Show-Gui
  # catch only sees a dispatcher-collapsed stack, which hid the real
  # frame twice - v421 search crash). Never throws.
  try {
    $diag = @()
    $diag += ('Date: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
    $diag += ('Where: ' + $where)
    $diag += ('Type: ' + $err.Exception.GetType().FullName)
    $diag += ('Message: ' + $err.Exception.Message)
    if ($err.InvocationInfo) { $diag += ('Line: ' + $err.InvocationInfo.ScriptLineNumber + ' : ' + [string]$err.InvocationInfo.Line) }
    $diag += 'Stack:'
    $diag += [string]$err.ScriptStackTrace
    ($diag -join [Environment]::NewLine) | Set-Content (Join-Path $PSScriptRoot 'gui-error.txt') -Encoding UTF8 -Force
  } catch { }
}

function Set-GuiTransientStatus([string]$text, [int]$seconds = 5) {
  # Show a result message in the status bar, then restore the tab status
  # after $seconds. A new message restarts the timer, so the latest result
  # always gets its full display time. (Without this, a result like
  # '0 updated, 5 already up to date.' overwrote the tab status forever.)
  if (-not $script:GuiStatusText) { return }
  $script:GuiStatusText.Text = $text
  if ($script:GuiStatusTimer) { try { $script:GuiStatusTimer.Stop() } catch { } }
  $timer = New-Object System.Windows.Threading.DispatcherTimer
  $timer.Interval = [TimeSpan]::FromSeconds($seconds)
  $timer.Add_Tick({
    try { $args[0].Stop() } catch { }
    try { Update-GuiStatusBar } catch { }
  })
  $script:GuiStatusTimer = $timer
  $timer.Start()
}

function Pump-GuiDispatcher {
  # Let the GUI process pending messages (paint + input) so the window
  # stays responsive during long operations. The Render-only Invoke in
  # Show-GuiProgress does NOT pump input, so Windows still flags the
  # window "Not Responding" when clicked. No-op when the GUI isn't open.
  try { if ($script:GuiWindow) { $script:GuiWindow.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Background, [System.Action]{}) } } catch { }
}

function Set-GuiBusy([bool]$busy) {
  # Disable the whole window during a long operation so a click can't
  # start a second operation re-entrantly mid-install. The window still
  # repaints and can be moved (the dispatcher is pumped); clicks are
  # just ignored until the operation finishes.
  if ($script:GuiWindow) { $script:GuiWindow.IsEnabled = -not $busy; if (-not $busy) { Pump-GuiDispatcher } }
}

function Invoke-SteamCmd([string[]]$sargs) {
  # Run SteamCMD, pumping the GUI dispatcher while it runs so the window
  # stays responsive (no "Not Responding") during downloads. Returns the
  # combined stdout+stderr lines. Output goes to temp files (not a
  # redirected pipe) so a large download can't deadlock on a full buffer.
  # Falls back to a plain synchronous call when the GUI isn't open.
  if (-not $script:GuiWindow) { return @(& $SteamCmdExe $sargs 2>&1 | ForEach-Object { $_.ToString() }) }
  $tmpOut = [IO.Path]::GetTempFileName()
  $tmpErr = [IO.Path]::GetTempFileName()
  try {
    $p = Start-Process -FilePath $SteamCmdExe -ArgumentList $sargs -NoNewWindow -PassThru -RedirectStandardOutput $tmpOut -RedirectStandardError $tmpErr
    while (-not $p.HasExited) { Pump-GuiDispatcher; Start-Sleep -Milliseconds 100 }
    $lines = @()
    if (Test-Path $tmpOut) { $lines += @(Get-Content $tmpOut -ErrorAction SilentlyContinue) }
    if (Test-Path $tmpErr) { $lines += @(Get-Content $tmpErr -ErrorAction SilentlyContinue) }
    return $lines
  } catch { return @() }
  finally { Remove-Item $tmpOut -ErrorAction SilentlyContinue; Remove-Item $tmpErr -ErrorAction SilentlyContinue }
}

function Show-GuiProgress([string]$text) {
  # Status-bar update for long GUI operations (install / update loops).
  # No-op when the GUI isn't open (text menu keeps its Write-Host lines).
  if ($script:GuiWindow -and $script:GuiStatusText) {
    $script:GuiStatusText.Text = $text
    $script:GuiWindow.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Render, [System.Action]{})
    Pump-GuiDispatcher
  }
}

function Show-GuiInstallProgress($n, $total, $name, $start, $verb) {
  # Per-mod progress: "[n/N] <verb> <name>... (elapsed MM:SS, ~MM:SS left)".
  # No-op when the GUI isn't open. The ETA is elapsed-average based.
  if (-not ($script:GuiWindow -and $script:GuiStatusText)) { return }
  $elapsed = (Get-Date) - $start
  $elapsedStr = ('{0}:{1:D2}' -f [int]$elapsed.TotalMinutes, $elapsed.Seconds)
  $eta = ''
  if ($n -gt 0 -and $total -gt $n) {
    $left = [int](($elapsed.TotalSeconds / $n) * ($total - $n))
    $eta = (', ~{0}:{1:D2} left' -f [int]($left / 60), ($left % 60))
  }
  Show-GuiProgress ("[{0}/{1}] {2} {3}... ({4}{5})" -f $n, $total, $verb, $name, $elapsedStr, $eta)
}


function Update-GuiStatusBar {
  # Bottom status bar follows the selected tab: Mods -> mod counts,
  # Packs -> pack counts, Lists -> list counts. Each refresh function stores
  # its tab's counts, then calls this; it always reports the selected tab.
  if (-not $script:GuiStatusText) { return }
  $idx = 0
  if ($script:GuiTabControl) { $idx = $script:GuiTabControl.SelectedIndex }
  if ($idx -eq 1) {
    $total = 0
    if ($script:GuiPacksTotal) { $total = $script:GuiPacksTotal }
    $shown = 0
    if ($script:GuiPacksShown -ne $null) { $shown = $script:GuiPacksShown }
    $modsTotal = 0
    if ($script:GuiPacksTotalMods) { $modsTotal = $script:GuiPacksTotalMods }
    if ($shown -eq $total) { $script:GuiStatusText.Text = ('{0} packs | {1} mods in packs' -f $total, $modsTotal) }
    else { $script:GuiStatusText.Text = ('Showing ' + $shown + ' of ' + $total + ' packs | ' + $modsTotal + ' mods in packs') }
  } elseif ($idx -eq 2) {
    $shown = 0
    if ($script:GuiCategoriesShown -ne $null) { $shown = $script:GuiCategoriesShown }
    $catModsTotal = 0
    if ($script:GuiCategoriesTotalMods) { $catModsTotal = $script:GuiCategoriesTotalMods }
    if ($shown -eq $script:GuiCategoriesTotal) { $script:GuiStatusText.Text = ('{0} categories | {1} mods in categories' -f $script:GuiCategoriesTotal, $catModsTotal) }
    else { $script:GuiStatusText.Text = ('Showing ' + $shown + ' of ' + $script:GuiCategoriesTotal + ' categories | ' + $catModsTotal + ' mods in categories') }
  } elseif ($idx -eq 3) {
    $total = 0
    if ($script:GuiListsTotal) { $total = $script:GuiListsTotal }
    $shown = 0
    if ($script:GuiListsShown -ne $null) { $shown = $script:GuiListsShown }
    if ($shown -eq $total) { $script:GuiStatusText.Text = ('{0} lists' -f $total) }
    else { $script:GuiStatusText.Text = ('Showing ' + $shown + ' of ' + $total + ' lists') }
  } else {
    $shown = 0
    if ($script:GuiModsShown -ne $null) { $shown = $script:GuiModsShown }
    $installed = 0
    if ($script:GuiModsInstalled -ne $null) { $installed = $script:GuiModsInstalled }
    $listName = 'No list'
    if ($script:GuiModsListName) { $listName = $script:GuiModsListName }
    if ($shown -eq $Mods.Count) { $script:GuiStatusText.Text = ('{0} mods | {1} installed in this list | List: {2}' -f $Mods.Count, $installed, $listName) }
    else { $script:GuiStatusText.Text = ('Showing ' + $shown + ' of ' + $Mods.Count + ' mods | ' + $installed + ' installed in this list | List: ' + $listName) }
  }
}

function Sort-GuiMods($list, $installed, $packNamesMap) {
  # Sort the Mods tab's shown mods. No sort column = list order.
  $col = $script:GuiModsSortColumn
  if ([string]$col -eq '') { return $list }
  $desc = [bool]$script:GuiModsSortDescending
  if ($col -eq 'Name') {
    if ($desc) { return @($list | Sort-Object Name -Descending) } else { return @($list | Sort-Object Name) }
  }
  if ($col -eq 'Category') {
    if ($desc) { return @($list | Sort-Object Cat, Name -Descending) } else { return @($list | Sort-Object Cat, Name) }
  }
  if ($col -eq 'Status') {
    if ($desc) { return @($list | Sort-Object { if ($installed -contains [string]$_.WorkshopId) { 0 } else { 1 } }, Name -Descending) } else { return @($list | Sort-Object { if ($installed -contains [string]$_.WorkshopId) { 0 } else { 1 } }, Name) }
  }
  if ($col -eq 'WorkshopId') {
    $key = { $v = 0; [void][long]::TryParse([string]$_.WorkshopId, [ref]$v); $v }
    if ($desc) { return @($list | Sort-Object $key, Name -Descending) } else { return @($list | Sort-Object $key, Name) }
  }
  if ($col -eq 'Packs') {
    $key = { $pn = ''; if ($packNamesMap -and $packNamesMap.ContainsKey([string]$_.WorkshopId)) { $pn = [string]$packNamesMap[[string]$_.WorkshopId] }; $pn }
    if ($desc) { return @($list | Sort-Object $key, Name -Descending) } else { return @($list | Sort-Object $key, Name) }
  }
  if ($col -eq 'Date') {
    $map = Get-InstallMap
    $key = { $dv = ''; if ($installed -contains [string]$_.WorkshopId) { if ($map -and $map.PSObject.Properties[[string]$_.WorkshopId]) { $v = $map.PSObject.Properties[[string]$_.WorkshopId].Value.installed_on; if ($v) { $dv = [string]$v } } }; $dv }
    if ($desc) { return @($list | Sort-Object $key, Name -Descending) } else { return @($list | Sort-Object $key, Name) }
  }
  if ($col -eq 'Size') {
    $map = Get-InstallMap
    $key = { $sv = [long]0; if ($installed -contains [string]$_.WorkshopId) { if ($map -and $map.PSObject.Properties[[string]$_.WorkshopId]) { $e = $map.PSObject.Properties[[string]$_.WorkshopId].Value; if ($e.PSObject.Properties['size'] -and $e.size) { $sv = [long]$e.size } else { $sv = Get-ModDiskSize @($e.folders) } } }; $sv }
    if ($desc) { return @($list | Sort-Object $key, Name -Descending) } else { return @($list | Sort-Object $key, Name) }
  }
  return $list
}

function Cycle-GuiModsSort([string]$col) {
  # Click a Mods header: toggle ascending <-> descending. Never clears.
  if ($script:GuiModsSortColumn -eq $col) {
    $script:GuiModsSortDescending = -not $script:GuiModsSortDescending
  } else {
    $script:GuiModsSortColumn = $col
    $script:GuiModsSortDescending = $false
  }
  Refresh-GuiMods
}

function Update-GuiWorkshopButtons {
  # Standard: View this mod on Workshop needs a HIGHLIGHTED row with
  # a numeric Workshop ID whose Name is not just the ID (an
  # unresolved entry has no real mod page). Browse Workshop is the
  # button for the main page, so View never duplicates it.
  $sel = $null; if ($script:GuiModList) { $sel = $script:GuiModList.SelectedItem }
  if ($script:GuiWorkshopButton) { $script:GuiWorkshopButton.IsEnabled = ($null -ne $sel -and [string]$sel.WorkshopId -match '^\d+$' -and [string]$sel.Name -ne '' -and [string]$sel.Name -ne [string]$sel.WorkshopId) }
  $sel = $null; if ($script:GuiPackMemberList) { $sel = $script:GuiPackMemberList.SelectedItem }
}

function Update-GuiSelectionButtons {
  # Refresh the Mods header bulk buttons: Install/Uninstall selected show
  # the selection count and disable at 0; Select-all toggles to Clear
  # selection when every shown mod is selected.
  $n = 0
  if ($script:GuiSelectedMods) { $n = $script:GuiSelectedMods.Count }
  if ($script:GuiInstallSelectedModsButton) {
    $script:GuiInstallSelectedModsButton.Content = ('Install Selected (' + $n + ')')
    $script:GuiInstallSelectedModsButton.IsEnabled = ($n -gt 0)
  }
  if ($script:GuiUninstallSelectedModsButton) {
    $script:GuiUninstallSelectedModsButton.Content = ('Uninstall Selected (' + $n + ')')
    $script:GuiUninstallSelectedModsButton.IsEnabled = ($n -gt 0)
  }
  # Standard: every button that needs a selection is disabled until
  # the selection meets its requirement (exactly one for View on
  # Workshop, at least one for the rest). Same rule on every tab.
  if ($script:GuiModRemoveFromListButton) { $script:GuiModRemoveFromListButton.IsEnabled = ($n -gt 0) }

  if ($script:GuiModMoveToCategoryButton) { $script:GuiModMoveToCategoryButton.IsEnabled = ($n -gt 0) }
  Sync-GuiHeaderCheckbox $script:GuiModList 'SelectAll' $script:GuiModsShownIds $script:GuiSelectedMods
}

function Toggle-GuiSelectAllPacks {
  # Header checkbox on the Packs table: select all shown packs or clear.
  if (-not $script:GuiSelectedPacks) { $script:GuiSelectedPacks = @{} }
  $allSelected = $false
  if ($script:GuiPacksShownIds -and $script:GuiPacksShownIds.Count -gt 0) {
    $allSelected = $true
    foreach ($name in @($script:GuiPacksShownIds.Keys)) { if (-not $script:GuiSelectedPacks.ContainsKey($name)) { $allSelected = $false; break } }
  }
  if ($allSelected) { $script:GuiSelectedPacks = @{} } else { foreach ($name in @($script:GuiPacksShownIds.Keys)) { $script:GuiSelectedPacks[$name] = $true } }
  $script:GuiPackSelectionDirty = $true
  Refresh-GuiPacks
}
function Sort-GuiPackMemberRows($rows) {
  $list = @($rows)
  if ($list.Count -le 1) { return ,$list }
  $col = $script:GuiPackMembersSortColumn; $desc = $script:GuiPackMembersSortDescending
  if ($col -eq 'Name') { if ($desc) { return @($list | Sort-Object Name -Descending) } else { return @($list | Sort-Object Name) } }
  if ($col -eq 'Category') { if ($desc) { return @($list | Sort-Object Category, Name -Descending) } else { return @($list | Sort-Object Category, Name) } }
  if ($col -eq 'Status') { if ($desc) { return @($list | Sort-Object Status, Name -Descending) } else { return @($list | Sort-Object Status, Name) } }
  if ($col -eq 'Date') { if ($desc) { return @($list | Sort-Object { [string]$_.InstalledDate }, Name -Descending) } else { return @($list | Sort-Object { [string]$_.InstalledDate }, Name) } }
  if ($col -eq 'Size') { if ($desc) { return @($list | Sort-Object { [long]$_.SizeBytes }, Name -Descending) } else { return @($list | Sort-Object { [long]$_.SizeBytes }, Name) } }
  if ($col -eq 'WorkshopId') { if ($desc) { return @($list | Sort-Object { [long]$_.WorkshopId }, Name -Descending) } else { return @($list | Sort-Object { [long]$_.WorkshopId }, Name) } }
  return ,$list
}
function Cycle-GuiPackMembersSort([string]$col) {
  if ($script:GuiPackMembersSortColumn -eq $col) {
    $script:GuiPackMembersSortDescending = -not $script:GuiPackMembersSortDescending
  } else { $script:GuiPackMembersSortColumn = $col; $script:GuiPackMembersSortDescending = $false }
  # Re-render the current detail pack with the new sort (keeps the pack).
  $dn = [string]$script:GuiPackDetailName
  $dp = $null
  if ($dn -ne '') { $dp = @(Get-AllPacks | Where-Object { $_.Name -eq $dn })[0] }
  Refresh-GuiPackDetail $dp
}

function Toggle-GuiSelectAllLists {
  # Header checkbox on the Lists table: select all shown named lists or clear.
  if (-not $script:GuiSelectedLists) { $script:GuiSelectedLists = @{} }
  $allSelected = $false
  if ($script:GuiListsShownIds -and $script:GuiListsShownIds.Count -gt 0) {
    $allSelected = $true
    foreach ($safe in @($script:GuiListsShownIds.Keys)) { if (-not $script:GuiSelectedLists.ContainsKey($safe)) { $allSelected = $false; break } }
  }
  if ($allSelected) { $script:GuiSelectedLists = @{} } else { foreach ($safe in @($script:GuiListsShownIds.Keys)) { $script:GuiSelectedLists[$safe] = $true } }
  $script:GuiListSelectionDirty = $true
  Refresh-GuiNamedLists
}
function Toggle-GuiSelectAllCategories {
  # Header checkbox on the Categories table: select all shown categories or clear.
  if (-not $script:GuiSelectedCategories) { $script:GuiSelectedCategories = @{} }
  $allSelected = $false
  if ($script:GuiCategoriesShownNames -and $script:GuiCategoriesShownNames.Count -gt 0) {
    $allSelected = $true
    foreach ($name in @($script:GuiCategoriesShownNames.Keys)) { if (-not $script:GuiSelectedCategories.ContainsKey($name)) { $allSelected = $false; break } }
  }
  if ($allSelected) { $script:GuiSelectedCategories = @{} } else { foreach ($name in @($script:GuiCategoriesShownNames.Keys)) { $script:GuiSelectedCategories[$name] = $true } }
  Refresh-GuiCategoriesTab
}
function Toggle-GuiSelectAllPackMembers {
  # Header checkbox on the Packs detail table: select all members of the
  # detail pack or clear (shared mod selection with the Mods tab).
  $detailName = [string]$script:GuiPackDetailName
  if ($detailName -eq '') { return }
  $pack = @(Get-AllPacks | Where-Object { $_.Name -eq $detailName })[0]
  if (-not $pack) { return }
  $members = @(Get-PackModsFull $pack)
  if (-not $script:GuiSelectedMods) { $script:GuiSelectedMods = @{} }
  $allSelected = ($members.Count -gt 0)
  foreach ($m in $members) { if (-not $script:GuiSelectedMods.ContainsKey([string]$m.WorkshopId)) { $allSelected = $false; break } }
  if ($allSelected) { foreach ($m in $members) { $script:GuiSelectedMods.Remove([string]$m.WorkshopId) } } else { foreach ($m in $members) { $script:GuiSelectedMods[[string]$m.WorkshopId] = $m.Name } }
  $script:GuiSelectionDirty = $true
  Refresh-GuiPacks
}

function Toggle-GuiSelectAllMods {
  # Select-all toggles: if every shown mod is selected, clear the whole
  # selection; otherwise select every shown mod (current filter).
  if (-not $script:GuiSelectedMods) { $script:GuiSelectedMods = @{} }
  $allSelected = $false
  if ($script:GuiModsShownIds -and $script:GuiModsShownIds.Count -gt 0) {
    $allSelected = $true
    foreach ($id in @($script:GuiModsShownIds.Keys)) { if (-not $script:GuiSelectedMods.ContainsKey($id)) { $allSelected = $false; break } }
  }
  if ($allSelected) {
    $script:GuiSelectedMods = @{}
  } else {
    foreach ($id in @($script:GuiModsShownIds.Keys)) {
      $m = @($Mods | Where-Object { [string]$_.WorkshopId -eq [string]$id })[0]
      if ($m) { $script:GuiSelectedMods[[string]$id] = $m.Name }
    }
  }
  $script:GuiSelectionDirty = $true
  Refresh-GuiMods
}

function Get-OrphanedAutoDeps {
  # Auto-added dependencies (autoDep) that no remaining INSTALLED mod
  # requires. A dep is orphaned only if: it is marked autoDep, it is
  # installed, and NONE of its Mod IDs appears in any remaining
  # installed mod's require=. Shared deps (required by another
  # installed mod) are never orphaned. A dep whose Mod ID cannot
  # be determined is kept (never remove what cannot be verified).
  $safe = Get-ActiveListSafe
  if ($safe -eq '') { return @() }
  $d = Get-NamedListData $safe
  if (-not $d) { return @() }
  $autoDeps = @($d.mods | Where-Object { [bool]$_.autoDep })
  if ($autoDeps.Count -eq 0) { return @() }
  $needed = @{}
  $map = Get-InstallMap
  if ($map) {
    foreach ($p in $map.PSObject.Properties) {
      if ([string]$p.Name -notmatch '^\d+$') { continue }
      if ($p.Value.installed -ne $true -or -not $p.Value.folders) { continue }
      foreach ($f in @($p.Value.folders)) {
        $mi = Join-Path (Join-Path $ModsDir ([string]$f)) 'mod.info'
        if (-not (Test-Path $mi)) { continue }
        $raw = ''; try { $raw = Get-Content $mi -Raw -ErrorAction Stop } catch { continue }
        $reqM = [regex]::Match($raw, '(?m)^\s*require\s*=\s*(.+?)\s*$')
        if ($reqM.Success) {
          foreach ($rid in @($reqM.Groups[1].Value -split '[,;]' | ForEach-Object { $_.Trim().TrimStart('\') } | Where-Object { $_ -ne '' })) {
            $needed[$rid] = $true
          }
        }
      }
    }
  }
  $orphans = @()
  foreach ($ad in $autoDeps) {
    $wid = [string]$ad.workshopId
    $installed = $false; $mids = @()
    if ($map -and $map.PSObject.Properties[$wid] -and $map.PSObject.Properties[$wid].Value.installed -eq $true) {
      foreach ($f in @($map.PSObject.Properties[$wid].Value.folders)) {
        $mi = Join-Path (Join-Path $ModsDir ([string]$f)) 'mod.info'
        if (-not (Test-Path $mi)) { continue }
        $installed = $true
        $m = Get-ModInfoId $mi
        if ($m -ne '' -and $mids -notcontains $m) { $mids += $m }
      }
    }
    if (-not $installed) { continue }
    if ($mids.Count -eq 0) { continue }
    $stillNeeded = $false
    foreach ($m in $mids) { if ($needed.ContainsKey($m)) { $stillNeeded = $true; break } }
    if ($stillNeeded) { continue }
    $orphans += [PSCustomObject]@{ WorkshopId = $wid; Name = [string]$ad.name; ModId = (($mids -join ', ')); Status = 'Orphaned - no installed mod requires it'; Details = ('Mod ID: ' + ($mids -join ', ') + "`n" + 'No remaining installed mod requires this dependency. It was auto-added when another mod needed it.') }
  }
  return $orphans
}

function Remove-ModFromActiveList([string]$workshopId) {
  # Remove one mod (by Workshop ID) from the active list file. No UI
  # refresh - the caller refreshes once at the end.
  $safe = Get-ActiveListSafe
  if ($safe -eq '') { return }
  $d = Get-NamedListData $safe
  if (-not $d) { return }
  $kept = @($d.mods | Where-Object { [string]$_.workshopId -ne [string]$workshopId })
  if ($kept.Count -eq @($d.mods).Count) { return }
  Save-NamedListData $safe $d.name $kept
}

function Uninstall-GuiSelectedMods {
  Clear-DiskModIdMap
  # Uninstall every checked mod (Mods tab). One confirm for the batch.
  if (-not $script:GuiSelectedMods -or $script:GuiSelectedMods.Count -eq 0) { Set-GuiTransientStatus ('Select at least one mod first.'); return }
  $ids = @($script:GuiSelectedMods.Keys)
  $res = Show-GuiMessageBox ('Uninstall ' + $ids.Count + ' selected mods?') 'PZ Mod Manager' ([System.Windows.MessageBoxButton]::YesNo) ([System.Windows.MessageBoxImage]::Warning)
  if ($res -ne [System.Windows.MessageBoxResult]::Yes) { return }
  Set-GuiBusy $true
  try {
  $ok = 0
  foreach ($id in $ids) { [void](Remove-WorkshopId $id); $ok++ }
  Set-GuiTransientStatus ('Done: ' + $ok + '/' + $ids.Count + ' selected mods uninstalled.')
  Clear-GuiSelection
  # Standard: refresh every view after uninstall (one composite call).
  # Orphaned dependencies: auto-added deps no remaining installed mod
  # requires (shared deps are never orphaned). ONE picker, unchecked
  # by default - tick the ones to remove (from the list AND uninstall).
  # Cancel / none selected = keep them all.
  $orphans = @(Get-OrphanedAutoDeps)
  if ($orphans.Count -gt 0) {
    $orpCols = @( @{ Header='Name'; Property='Name'; Width=400 }, @{ Header='Workshop ID'; Property='WorkshopId'; Width=150 }, @{ Header='Status'; Property='Status'; Width=400 } )
    $orpCands = @()
    foreach ($o in $orphans) { $orpCands += [PSCustomObject]@{ Name = [string]$o.Name; WorkshopId = [string]$o.WorkshopId; Cat = ''; Status = [string]$o.Status; Details = [string]$o.Details; IsChecked = $false } }
    $orpRes = Show-GuiWpfPicker 'Orphaned Dependencies' 'These auto-added dependencies are no longer required by any installed mod. Select the ones to remove (they will be removed from the list and uninstalled).' $orpCands $orpCols 'Remove Selected'
    if (-not $orpRes.Failed -and $orpRes.Selected) {
      foreach ($sel in @($orpRes.Selected)) {
        Remove-ModFromActiveList [string]$sel.WorkshopId
        [void](Remove-WorkshopId [string]$sel.WorkshopId)
      }
    }
  }
  Refresh-GuiAfterListChange
  } finally { Set-GuiBusy $false }
}


function Refresh-GuiMods {
  # Mods tab is a ListView + GridView (Explorer Details view): one shared
  # column set, header dividers drag to resize (WPF's own GridView
  # grip - no custom resize code), click a header to sort. Rows are
  # plain item objects; the GridView binds their properties to cells.
  # Shows the ACTIVE list's mods ($Mods is the active list's working set).
  if (-not $script:GuiModList) { return }
  # Reload first: $Mods must match the list file, or a removed mod
  # stays visible (the file is the source of truth; $Mods is a cache).
  $act0 = Get-ActiveListSafe
  if ($act0 -ne '') { [void](Set-ModsFromNamedList $act0) }
  if (-not $script:GuiSelectedMods) { $script:GuiSelectedMods = @{} }
  $installed = @(Get-InstalledWorkshopIds)
  $search = ''
  if ($script:GuiSearchBox) { $search = [string]$script:GuiSearchBox.Text }
  $search = $search.Trim()
  $cat = $script:GuiCategory
  if ([string]$cat -eq '') { $cat = 'All categories' }
  $packFilter = $script:GuiPackFilter
  if ([string]$packFilter -eq '') { $packFilter = 'All packs' }
  $packMemberIds = $null
  if ($packFilter -ne 'All packs') {
    $selPack = @(Get-AllPacks | Where-Object { [string]$_.Name -eq $packFilter })[0]
    $packMemberIds = @{}
    if ($selPack) { foreach ($pm in @(Get-PackMods $selPack)) { $packMemberIds[[string]$pm.WorkshopId] = $true } }
  }
  $installedCount = @($Mods | Where-Object { $installed -contains [string]$_.WorkshopId }).Count
  $shown = 0
  $display = @()
  foreach ($m in (Get-DisplayMods)) {
    $isInstalled = $installed -contains [string]$m.WorkshopId
    if ($cat -eq 'Installed') {
      if (-not $isInstalled) { continue }
    } elseif ($cat -eq 'Not Installed') {
      if ($isInstalled) { continue }
    } elseif ($cat -ne 'All categories' -and $m.Cat -ne $cat) { continue }
    if ($packMemberIds -and -not $packMemberIds.ContainsKey([string]$m.WorkshopId)) { continue }
    if ($search -ne '' -and $m.Name -notmatch [regex]::Escape($search)) { continue }
    $display += $m
  }
  $packNamesMap = @{}
  foreach ($pack in @(Get-AllPacks)) {
    foreach ($pm in @(Get-PackMods $pack)) {
      $modId = [string]$pm.WorkshopId
      if (-not $packNamesMap.ContainsKey($modId)) { $packNamesMap[$modId] = @() }
      $packNamesMap[$modId] += [string]$pack.Name
    }
  }
  foreach ($modId in @($packNamesMap.Keys)) { $packNamesMap[$modId] = (@($packNamesMap[$modId] | Sort-Object -Unique) -join ', ') }
  $display = Sort-GuiMods $display $installed $packNamesMap
  $script:GuiModsShownIds = @{}
  foreach ($m in $display) { $script:GuiModsShownIds[[string]$m.WorkshopId] = $true }
  $installMap = Get-InstallMap
  $items = @()
  foreach ($m in $display) {
    $isInstalled = $installed -contains [string]$m.WorkshopId
    $shown++
    $packNames = ''
    if ($packNamesMap.ContainsKey([string]$m.WorkshopId)) { $packNames = [string]$packNamesMap[[string]$m.WorkshopId] }
    $status = 'Not installed'
    if ($isInstalled) { $status = 'Installed' }
    # Date = installed date, shown ONLY when the mod is installed.
    # A not-installed mod keeps its install-map record (update
    # detection), but showing its stale date is misleading.
    $dateVal = ''
    $sizeBytes = [long]0
    if ($isInstalled -and $installMap -and $installMap.PSObject.Properties[[string]$m.WorkshopId]) {
      $entry0 = $installMap.PSObject.Properties[[string]$m.WorkshopId].Value
      $dv = $entry0.installed_on
      if ($dv) { $dateVal = [string]$dv }
      # Size = stored at install/update; entries from before the
      # Size column are measured once here and written back.
      if ($entry0.PSObject.Properties['size'] -and $entry0.size) { $sizeBytes = [long]$entry0.size }
      else {
        $sizeBytes = Get-ModDiskSize @($entry0.folders)
        $entry0 | Add-Member -NotePropertyName 'size' -NotePropertyValue $sizeBytes -Force
        $script:GuiSizeBackfilled = $true
      }
    }
    $items += [PSCustomObject]@{
      Name = [string]$m.Name
      Category = [string]$m.Cat
      Status = $status
      WorkshopId = [string]$m.WorkshopId
      Date = $dateVal
      Size = (Format-ModSize $sizeBytes)
      SizeBytes = [long]$sizeBytes
      Packs = $packNames
      IsChecked = $script:GuiSelectedMods.ContainsKey([string]$m.WorkshopId)
    }
  }
  if ($script:GuiSizeBackfilled) { $script:GuiSizeBackfilled = $false; Save-InstallMap $installMap }
  $script:GuiModList.ItemsSource = $items
  # Header select-all checkbox (GridView checkbox column): checked = all
  # shown selected, unchecked = none, indeterminate = partial.
  if ($script:GuiModList.View -and $script:GuiModList.View.Columns -and $script:GuiModList.View.Columns.Count -gt 0) {
    $hdrCb = $script:GuiModList.View.Columns[0].Header
    if ($hdrCb -is [System.Windows.Controls.CheckBox]) {
      $selCount = 0
      foreach ($id in @($script:GuiModsShownIds.Keys)) { if ($script:GuiSelectedMods.ContainsKey($id)) { $selCount++ } }
      if ($script:GuiModsShownIds.Count -eq 0 -or $selCount -eq 0) { $hdrCb.IsChecked = $false }
      elseif ($selCount -eq $script:GuiModsShownIds.Count) { $hdrCb.IsChecked = $true }
      else { $hdrCb.IsChecked = $false }
    }
  }
  # GridView header sort indicators (reset to plain, then mark the sorted one).
  if ($script:GuiModList.View -and $script:GuiModList.View.Columns) {
    $gvCols = $script:GuiModList.View.Columns
    $plain = @('Name', 'Category', 'Status', 'Workshop ID', 'Installed Date', 'Size', 'Packs')
    for ($i = 0; $i -lt 7 -and ($i + 1) -lt $gvCols.Count; $i++) { $gvCols[$i + 1].Header = $plain[$i] }
    if ($script:GuiModsSortColumn -eq 'Name') { $gvCols[1].Header = if ($script:GuiModsSortDescending) { 'Name (Z-A)' } else { 'Name (A-Z)' } }
    elseif ($script:GuiModsSortColumn -eq 'Category') { $gvCols[2].Header = if ($script:GuiModsSortDescending) { 'Category (Z-A)' } else { 'Category (A-Z)' } }
    elseif ($script:GuiModsSortColumn -eq 'Status') { $gvCols[3].Header = if ($script:GuiModsSortDescending) { 'Status (Not installed first)' } else { 'Status (Installed first)' } }
    elseif ($script:GuiModsSortColumn -eq 'WorkshopId') { $gvCols[4].Header = if ($script:GuiModsSortDescending) { 'Workshop ID (9-0)' } else { 'Workshop ID (0-9)' } }
    elseif ($script:GuiModsSortColumn -eq 'Date') { $gvCols[5].Header = if ($script:GuiModsSortDescending) { 'Installed Date (newest)' } else { 'Installed Date (oldest)' } }
    elseif ($script:GuiModsSortColumn -eq 'Size') { $gvCols[6].Header = if ($script:GuiModsSortDescending) { 'Size (9-0)' } else { 'Size (0-9)' } }
    elseif ($script:GuiModsSortColumn -eq 'Packs') { $gvCols[7].Header = if ($script:GuiModsSortDescending) { 'Packs (Z-A)' } else { 'Packs (A-Z)' } }
  }
  $listName = ''
  $active = Get-ActiveListSafe
  if ($active -ne '') {
    $match = @(Get-NamedLists | Where-Object { $_.Safe -eq $active })[0]
    if ($match) { $listName = $match.Name }
  }
  if ($listName -eq '') { $listName = 'No list' }
  Update-GuiSelectionButtons
  $script:GuiModsShown = $shown
  $script:GuiModsInstalled = $installedCount
  $script:GuiModsListName = $listName
  Update-GuiStatusBar
  Sync-GuiHeaderCheckbox $script:GuiModList 'SelectAll' $script:GuiModsShownIds $script:GuiSelectedMods
}

function Initialize-ConsoleHider {
  if (([System.Management.Automation.PSTypeName]'Win32.ConsoleHider').Type) { return }
  Add-Type -Name ConsoleHider -Namespace Win32 -MemberDefinition '[DllImport("kernel32.dll")] public static extern System.IntPtr GetConsoleWindow(); [DllImport("user32.dll")] public static extern bool ShowWindow(System.IntPtr hWnd, int nCmdShow); [DllImport("user32.dll")] public static extern System.IntPtr GetForegroundWindow(); [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(System.IntPtr hWnd, out uint lpdwProcessId); [DllImport("user32.dll")] public static extern int GetWindowLong(System.IntPtr hWnd, int nIndex); [DllImport("user32.dll")] public static extern int SetWindowLong(System.IntPtr hWnd, int nIndex, int dwNewLong); [DllImport("user32.dll")] public static extern bool SetWindowPos(System.IntPtr hWnd, System.IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags); [DllImport("gdi32.dll")] public static extern bool DeleteObject(System.IntPtr hObject); [DllImport("user32.dll")] public static extern System.IntPtr SendMessage(System.IntPtr hWnd, uint Msg, System.IntPtr wParam, System.IntPtr lParam); [DllImport("shell32.dll")] public static extern int SetCurrentProcessExplicitAppUserModelID([System.Runtime.InteropServices.MarshalAs(System.Runtime.InteropServices.UnmanagedType.LPWStr)] string AppID);'
}

function Write-GuiHideDebug([string]$Line) {
  # No-op: debug logging to gui-hide-debug.txt removed (v224). The file
  # kept reappearing because Show-Gui rewrote it on every launch.
  # Call sites are left as no-ops (they share lines with real logic).
}

function Get-TerminalHostHandles {
  # Main window of every terminal host process (WindowsTerminal/wt/conhost).
  # Windows Terminal is NOT an ancestor of this process (console hosted via
  # ConPTY), so the parent chain cannot find it; EnumWindows via a scriptblock
  # delegate proved fragile, so use each host process's MainWindowHandle.
  try {
    Initialize-ConsoleHider
    $out = @()
    $fg = [Win32.ConsoleHider]::GetForegroundWindow()
    if ($fg -ne [System.IntPtr]::Zero) {
      $procId = [uint32]0
      [void][Win32.ConsoleHider]::GetWindowThreadProcessId($fg, [ref]$procId)
      $proc = Get-Process -Id $procId -ErrorAction SilentlyContinue
      if ($proc -and $proc.ProcessName -match '^(WindowsTerminal|wt|conhost|WindowsTerminalPreview)$') { $out += $fg }
    }
    foreach ($pn in @('WindowsTerminal','wt','WindowsTerminalPreview','conhost')) {
      foreach ($p in @(Get-Process -Name $pn -ErrorAction SilentlyContinue)) {
        Write-GuiHideDebug ('host proc: ' + $p.ProcessName + ' id=' + $p.Id + ' mainTitle=[' + $p.MainWindowTitle + '] handle=' + $p.MainWindowHandle)
        if ($p.MainWindowHandle -ne [System.IntPtr]::Zero) { $out += $p.MainWindowHandle }
      }
    }
    return @($out | Select-Object -Unique)
  } catch { return @() }
}

# Hide the console + terminal host windows: remove from the taskbar (tool-window
# style) and hide. Never throws: if it fails, the console just stays visible.
# Hidden handles + original styles are tracked so Show-Console restores exactly them.
function Hide-Console {
  try {
    Initialize-ConsoleHider
    $handles = @()
    $console = [Win32.ConsoleHider]::GetConsoleWindow()
    if ($console -ne [System.IntPtr]::Zero) { $handles += $console }
    foreach ($h in (Get-TerminalHostHandles)) {
      if ($h -ne [System.IntPtr]::Zero -and $h -notin $handles) { $handles += $h }
    }
    $script:HiddenWindowHandles = @($handles)
    $script:HiddenWindowStyles = @{}
    Write-GuiHideDebug ('hide: console=' + $console.ToString() + ' hosts=' + (($handles | ForEach-Object { $_.ToString() }) -join ','))
    foreach ($h in $handles) {
      $orig = [Win32.ConsoleHider]::GetWindowLong($h, -20)
      $script:HiddenWindowStyles[$h] = $orig
      [void][Win32.ConsoleHider]::SetWindowLong($h, -20, ($orig -bor 0x80))
      [void][Win32.ConsoleHider]::SetWindowPos($h, [System.IntPtr]::Zero, 0, 0, 0, 0, 0x27)
      [void][Win32.ConsoleHider]::ShowWindow($h, 0)
    }
  } catch { }
}

function Show-Console {
  try {
    Initialize-ConsoleHider
    foreach ($h in @($script:HiddenWindowHandles)) {
      if ($h -eq [System.IntPtr]::Zero) { continue }
      if ($script:HiddenWindowStyles -and $script:HiddenWindowStyles.ContainsKey($h)) {
        [void][Win32.ConsoleHider]::SetWindowLong($h, -20, $script:HiddenWindowStyles[$h])
        [void][Win32.ConsoleHider]::SetWindowPos($h, [System.IntPtr]::Zero, 0, 0, 0, 0, 0x27)
      }
      [void][Win32.ConsoleHider]::ShowWindow($h, 1)
    }
    $script:HiddenWindowHandles = @()
    $script:HiddenWindowStyles = @{}
  } catch { }
}

$script:GuiPackDetailName = ''

function Get-PackMods($pack, $catalog, [switch]$IncludeUnknown) {
  if (-not $catalog) { $catalog = $Mods }
  $ids = Expand-PackIds $pack $catalog
  $out = @()
  foreach ($id in $ids) {
    $found = @($catalog | Where-Object { [string]$_.WorkshopId -eq [string]$id })[0]
    if ($found) { $out += $found } elseif ($IncludeUnknown) {
      # Member not in the catalog (added by ID): show it with its Steam
      # title (cached) instead of dropping it, so it can be
      # installed/uninstalled like any member. Only for full-catalog
      # callers (Get-PackModsFull): working-set callers must NOT get
      # placeholders, or the Packs tab's "hide packs with 0 members in the
      # active list" check never fires and every Default pack shows on a
      # custom list.
      $nm = Get-WorkshopModName ([string]$id)
      if (-not $nm) { $nm = [string]$id }
      $out += [PSCustomObject]@{ WorkshopId = [string]$id; Name = [string]$nm; Cat = 'Others' }
    }
  }
  return $out
}

function Get-PackModsFull($pack) {
  # A pack's full member list, resolved against the whole catalog (not the
  # current working set) - for adding a pack to a custom list.
  Get-PackMods $pack (Get-FullModCatalog) -IncludeUnknown
}

function New-GuiCustomPack {
  $nm = Read-GuiInput 'Name for the new pack' 'PZ Mod Manager' ''
  if (-not $nm) { return }
  $allPacks = @(Get-AllPacks)
  if (@($allPacks | Where-Object { $_.Name -eq $nm }).Count -gt 0) {
    Set-GuiTransientStatus ("A pack named '" + $nm + "' already exists.")
    return
  }
  $desc = Read-GuiInput 'Description for the new pack' 'PZ Mod Manager' ''
  if ($null -eq $desc) { $desc = '' }
  $customPacks = @(Get-CustomPacks)
  $customPacks += @{ Name = $nm; Desc = $desc; Ids = @(); List = (Get-ActiveListSafe); Created = (Get-Date -Format 'yyyy-MM-dd') }
  Save-CustomPacks $customPacks
  Remove-RemovedPackName (Get-ActiveListSafe) $nm
  $script:GuiPackDetailName = $nm
  Set-GuiTransientStatus ("Created pack '" + $nm + "'. Add members below.")
  # Standard: refresh every view after this change (one composite call).
  Refresh-GuiAfterListChange
}

function Reset-GuiCustomPack([string]$packName) {
  # Factory reset for a duplicated pack: restore its members to its
  # built-in source's current members (discards the copy's edits).
  # Only packs duplicated from a built-in pack have a Source.
  $customPacks = @(Get-CustomPacks)
  $activeList = Get-ActiveListSafe
  $target = @($customPacks | Where-Object { $_.Name -eq $packName -and [string]$_.List -eq $activeList })[0]
  if (-not $target) { return }
  $sourceName = [string]$target.Source
  if ($sourceName -eq '') { return }
  $source = @(Get-AllPacks -AllLists | Where-Object { $_.Name -eq $sourceName -and -not $_.Custom })[0]
  if (-not $source) { Set-GuiTransientStatus (("Can't reset: built-in pack '" + $sourceName + "' no longer exists.")); return }
  $res = Show-GuiMessageBox ('Reset "' + $packName + '" to match built-in pack "' + $sourceName + '"? This discards your edits to the copy.') 'PZ Mod Manager' ([System.Windows.MessageBoxButton]::YesNo) ([System.Windows.MessageBoxImage]::Warning)
  if ($res -ne [System.Windows.MessageBoxResult]::Yes) { return }
  $target.Ids = @(@(Get-PackModsFull $source) | ForEach-Object { [string]$_.WorkshopId })
  Save-CustomPacks $customPacks
  Set-GuiTransientStatus (("Reset '" + $packName + "' to built-in pack '" + $sourceName + "' (" + $target.Ids.Count + " mods)."))
  # Standard: refresh every view after this change (one composite call).
  Refresh-GuiAfterListChange
}

function Edit-GuiPackDescription([string]$packName) {
  # Edit any pack's description. A custom pack edits in place; a
  # built-in pack converts to a custom copy (same name) carrying the
  # new description.
  $allPacks = @(Get-AllPacks)
  $pack = @($allPacks | Where-Object { $_.Name -eq $packName })[0]
  if (-not $pack) { return }
  $newDesc = Read-GuiInput 'Description for the pack' 'PZ Mod Manager' ([string]$pack.Desc)
  if ($null -eq $newDesc -or $newDesc -eq [string]$pack.Desc) { return }
  $customPacks = @(Get-CustomPacks)
  $activeList = Get-ActiveListSafe
  $target = @($customPacks | Where-Object { $_.Name -eq $packName -and [string]$_.List -eq $activeList })[0]
  if ($target) {
    $target.Desc = $newDesc
  } else {
    $customPacks += @{ Name = $packName; Desc = $newDesc; Ids = @($pack.Ids); Source = $packName; List = $activeList; Created = (Get-Date -Format 'yyyy-MM-dd') }
  }
  Save-CustomPacks $customPacks
  Set-GuiTransientStatus ("Updated description of '" + $packName + "'.")
  Refresh-GuiAfterListChange
}

function Rename-GuiCustomPack([string]$oldName) {
  # Rename any pack in the active list. A custom pack renames in
  # place; a built-in pack converts to a custom copy under the new
  # name and the built-in name is tombstoned for this list.
  $newName = Read-GuiInput 'New name for the pack' 'PZ Mod Manager' $oldName
  if (-not $newName -or $newName -eq $oldName) { return }
  $allPacks = @(Get-AllPacks)
  if (@($allPacks | Where-Object { $_.Name -eq $newName }).Count -gt 0) {
    Set-GuiTransientStatus ("A pack named '" + $newName + "' already exists.")
    return
  }
  $customPacks = @(Get-CustomPacks)
  $activeList = Get-ActiveListSafe
  $target = @($customPacks | Where-Object { $_.Name -eq $oldName -and [string]$_.List -eq $activeList })[0]
  if ($target) {
    $target.Name = $newName
    Save-CustomPacks $customPacks
    # If this was a same-name copy of a built-in, the built-in would
    # reappear under the old name - tombstone it for this list.
    if (@($Packs | ForEach-Object { [string]$_.Name }) -contains $oldName) { Add-RemovedPackName $activeList $oldName }
  } else {
    $builtin = @($allPacks | Where-Object { $_.Name -eq $oldName -and -not $_.Custom })[0]
    if (-not $builtin) { return }
    $customPacks += @{ Name = $newName; Desc = [string]$builtin.Desc; Ids = @($builtin.Ids); Source = $oldName; List = $activeList; Created = (Get-Date -Format 'yyyy-MM-dd') }
    Save-CustomPacks $customPacks
    Add-RemovedPackName $activeList $oldName
  }
  Remove-RemovedPackName $activeList $newName
  # Keep the selection on the renamed pack: the selection is keyed by
  # name, so move the old key to the new name (same stale-key bug).
  if ($script:GuiSelectedPacks -and $script:GuiSelectedPacks.ContainsKey($oldName)) {
    $script:GuiSelectedPacks.Remove($oldName)
    $script:GuiSelectedPacks[$newName] = $true
  }
  if ($script:GuiPackDetailName -eq $oldName) { $script:GuiPackDetailName = $newName }
  Set-GuiTransientStatus ("Renamed pack to '" + $newName + "'.")
  # Standard: refresh every view after this change (one composite call).
  Refresh-GuiAfterListChange
}


function Add-GuiPackMembers([string]$packName, $entries) {
  # Adds one or more mods to a pack in a single save (dedup by ID).
  # For a built-in pack this creates the custom override (same name,
  # Source = built-in) so the add lands on the existing pack, not a copy.
  $customPacks = @(Get-CustomPacks)
  $activeList = Get-ActiveListSafe
  $target = @($customPacks | Where-Object { $_.Name -eq $packName -and [string]$_.List -eq $activeList })[0]
  if (-not $target) {
    $builtin = @(Get-AllPacks | Where-Object { $_.Name -eq $packName -and -not $_.Custom })[0]
    if (-not $builtin) { return }
    $ids = @(@(Get-PackModsFull $builtin) | ForEach-Object { [string]$_.WorkshopId })
    $target = @{ Name = [string]$builtin.Name; Desc = $builtin.Desc; Ids = $ids; Source = [string]$builtin.Name; List = $activeList }
    $customPacks += $target
  }
  $have = @{}
  foreach ($id in $target.Ids) { $have[[string]$id] = $true }
  $added = 0
  foreach ($e in $entries) {
    if (-not $have.ContainsKey([string]$e.WorkshopId)) {
      $target.Ids += [string]$e.WorkshopId
      $have[[string]$e.WorkshopId] = $true
      $added++
    }
  }
  if ($added -eq 0) { Set-GuiTransientStatus ('Already in pack.'); return }
  Save-CustomPacks $customPacks
  # Also add to the active list, so the mod shows in both the pack and the list.
  Add-EntriesToActiveList $entries
  Set-GuiTransientStatus (("Added " + $added + " mod(s) to pack + active list."))
  Refresh-GuiAfterListChange
}

function Update-GuiPackSelectionButtons {
  # Refresh the Packs header bulk buttons: Install/Uninstall/Hide selected
  # show the selection count and disable at 0; Select-all toggles to
  # Clear selection when every shown pack is selected.
  $n = 0
  if ($script:GuiSelectedPacks) { $n = $script:GuiSelectedPacks.Count }
  if ($script:GuiPackRenameDeleteButton) {
    # Merged Rename / Delete: enabled when anything is checked; the
    # menu itself gates Rename / Edit Description / Delete by count.
    $script:GuiPackRenameDeleteButton.IsEnabled = ($n -gt 0)
  }
  # Member (mod) sub-selection: checked pack members feed the shared
  # mod selection; these buttons act on them in place.
  $nm = 0
  if ($script:GuiSelectedMods) { $nm = $script:GuiSelectedMods.Count }
  # Standard: selection-requiring buttons disabled until the
  # requirement is met. Detail-pack buttons need a pack in detail
  # (GuiPackDetailName); member buttons need checked members.
  $hasDetail = ([string]$script:GuiPackDetailName -ne '')
  if ($script:GuiPackMemberAddButton) { $script:GuiPackMemberAddButton.IsEnabled = $hasDetail }
  if ($script:GuiPackMemberAddFromListButton) { $script:GuiPackMemberAddFromListButton.IsEnabled = $hasDetail }
  if ($script:GuiPackResetButton) { $script:GuiPackResetButton.IsEnabled = $hasDetail }
  if ($script:GuiPackMemberRemoveButton) { $script:GuiPackMemberRemoveButton.IsEnabled = ($nm -gt 0) }
  Sync-GuiHeaderCheckbox $script:GuiPackList 'SelectAllPacks' $script:GuiPacksShownIds $script:GuiSelectedPacks
}


function Cycle-GuiPacksSort([string]$col) {
  # Click a Packs header: toggle ascending <-> descending. Never clears.
  if ($script:GuiPacksSortColumn -eq $col) {
    $script:GuiPacksSortDescending = -not $script:GuiPacksSortDescending
  } else { $script:GuiPacksSortColumn = $col; $script:GuiPacksSortDescending = $false }
  Refresh-GuiPacks
}
function Refresh-GuiPacks {
  # Packs tab is a ListView + GridView (same table layout as the Mods tab):
  # one row per pack, sortable headers, resizable columns. The selected
  # pack's members show in the detail table below (Add / Remove / Rename /
  # Delete / Reset there), replacing the old +/- expander rows.
  # Shows the ACTIVE list's packs (Get-AllPacks is scoped to it).
  if (-not $script:GuiPackList) { return }
  if ($script:GuiRefreshingPacks) { return }
  $script:GuiRefreshingPacks = $true
  try {
    if (-not $script:GuiSelectedPacks) { $script:GuiSelectedPacks = @{} }
    if (-not $script:GuiSelectedMods) { $script:GuiSelectedMods = @{} }
    $script:GuiPacksShownIds = @{}
    $installed = @(Get-InstalledWorkshopIds)
    $search = ''
    if ($script:GuiPackSearch) { $search = [string]$script:GuiPackSearch }
    $search = $search.Trim()
    $shownPacks = @()
    foreach ($pack in (Get-AllPacks)) {
      if ($search -ne '' -and $pack.Name -notmatch [regex]::Escape($search) -and $pack.Desc -notmatch [regex]::Escape($search)) { continue }
      $packMods = @(Get-PackMods $pack)
      if (-not $pack.Custom -and $packMods.Count -eq 0) { continue }
      $shownPacks += $pack
    }
    # Drop stale selection keys (a pack renamed/deleted without moving
    # its key): the count must match what's actually selected. Prune
    # against ALL packs, not just the search-filtered shown ones.
    $allPackNames = @(Get-AllPacks | ForEach-Object { [string]$_.Name })
    foreach ($k in @($script:GuiSelectedPacks.Keys)) { if ($allPackNames -notcontains $k) { $script:GuiSelectedPacks.Remove($k) } }
    $col = $script:GuiPacksSortColumn
    if ($col -eq 'Name') { if ($script:GuiPacksSortDescending) { $shownPacks = @($shownPacks | Sort-Object Name -Descending) } else { $shownPacks = @($shownPacks | Sort-Object Name) } }
    elseif ($col -eq 'Description') { if ($script:GuiPacksSortDescending) { $shownPacks = @($shownPacks | Sort-Object Desc -Descending) } else { $shownPacks = @($shownPacks | Sort-Object Desc) } }
    elseif ($col -eq 'Mods') { if ($script:GuiPacksSortDescending) { $shownPacks = @($shownPacks | Sort-Object { @(Get-PackMods $_).Count }, Name -Descending) } else { $shownPacks = @($shownPacks | Sort-Object { @(Get-PackMods $_).Count }, Name) } }
    elseif ($col -eq 'Installed') { if ($script:GuiPacksSortDescending) { $shownPacks = @($shownPacks | Sort-Object { @(@(Get-PackMods $_) | Where-Object { $installed -contains [string]$_.WorkshopId }).Count }, Name -Descending) } else { $shownPacks = @($shownPacks | Sort-Object { @(@(Get-PackMods $_) | Where-Object { $installed -contains [string]$_.WorkshopId }).Count }, Name) } }
    elseif ($col -eq 'Date') { if ($script:GuiPacksSortDescending) { $shownPacks = @($shownPacks | Sort-Object { [string]$_.Created }, Name -Descending) } else { $shownPacks = @($shownPacks | Sort-Object { [string]$_.Created }, Name) } }
    $items = @()
    foreach ($pack in $shownPacks) {
      $script:GuiPacksShownIds[$pack.Name] = $true
      $packMods = @(Get-PackMods $pack)
      $n = @($packMods | Where-Object { $installed -contains [string]$_.WorkshopId }).Count
      $items += [PSCustomObject]@{
        Name = [string]$pack.Name
        Description = [string]$pack.Desc
        Mods = $packMods.Count
        Date = [string]$pack.Created
        Installed = ('{0}/{1}' -f $n, $packMods.Count)
        IsChecked = $script:GuiSelectedPacks.ContainsKey($pack.Name)
      }
    }
    $script:GuiPackList.ItemsSource = $items
    # Header select-all checkbox (pack table).
    if ($script:GuiPackList.View -and $script:GuiPackList.View.Columns -and $script:GuiPackList.View.Columns.Count -gt 0) {
      $hdrCb = $script:GuiPackList.View.Columns[0].Header
      if ($hdrCb -is [System.Windows.Controls.CheckBox]) {
        $selCount = 0
        foreach ($id in @($script:GuiPacksShownIds.Keys)) { if ($script:GuiSelectedPacks.ContainsKey($id)) { $selCount++ } }
        if ($script:GuiPacksShownIds.Count -eq 0 -or $selCount -eq 0) { $hdrCb.IsChecked = $false }
        elseif ($selCount -eq $script:GuiPacksShownIds.Count) { $hdrCb.IsChecked = $true }
        else { $hdrCb.IsChecked = $false }
      }
    }
    # Header sort indicators.
    if ($script:GuiPackList.View -and $script:GuiPackList.View.Columns) {
      $gvCols = $script:GuiPackList.View.Columns
      $plain = @('Name', 'Installed', 'Description')
      for ($i = 0; $i -lt 3 -and ($i + 1) -lt $gvCols.Count; $i++) { $gvCols[$i + 1].Header = $plain[$i] }
      if ($col -eq 'Name') { $gvCols[1].Header = if ($script:GuiPacksSortDescending) { 'Name (Z-A)' } else { 'Name (A-Z)' } }
      elseif ($col -eq 'Installed') { $gvCols[2].Header = if ($script:GuiPacksSortDescending) { 'Installed (9-0)' } else { 'Installed (0-9)' } }
      elseif ($col -eq 'Description') { $gvCols[3].Header = if ($script:GuiPacksSortDescending) { 'Description (Z-A)' } else { 'Description (A-Z)' } }
    }
    # Detail pane: members of the detail pack (first shown pack by default,
    # or the pack the user clicked). The detail pack survives refreshes.
    $detailName = [string]$script:GuiPackDetailName
    $detailPack = $null
    if ($detailName -ne '') { $detailPack = @($shownPacks | Where-Object { $_.Name -eq $detailName })[0] }
    if (-not $detailPack -and $shownPacks.Count -gt 0) { $detailPack = $shownPacks[0]; $script:GuiPackDetailName = [string]$detailPack.Name }
    if (-not $detailPack) { $script:GuiPackDetailName = '' }
    Refresh-GuiPackDetail $detailPack
    $script:GuiPacksShown = $shownPacks.Count
    $script:GuiPacksTotal = @(Get-AllPacks).Count
    $packsTotalMods = 0
    foreach ($p in (Get-AllPacks)) { $packsTotalMods += @(Get-PackMods $p).Count }
    $script:GuiPacksTotalMods = $packsTotalMods
    Update-GuiPackSelectionButtons
    Update-GuiStatusBar
  } finally {
    $script:GuiRefreshingPacks = $false
  }

  Sync-GuiHeaderCheckbox $script:GuiPackList 'SelectAllPacks' $script:GuiPacksShownIds $script:GuiSelectedPacks
}

function Refresh-GuiPackDetail($pack) {
  # Detail table under the Packs list: the detail pack's members + the
  # Add / Remove / Rename / Delete / Reset controls for that pack.
  if (-not $script:GuiPackMemberList) { return }
  if (-not $pack) {
    $script:GuiPackMemberList.ItemsSource = @()
    if ($script:GuiPackMemberLabel) { $script:GuiPackMemberLabel.Text = 'Mods' }
    if ($script:GuiPackResetButton) { $script:GuiPackResetButton.Visibility = [System.Windows.Visibility]::Collapsed }
    return
  }
  $installed = @(Get-InstalledWorkshopIds)
  $installMap = Get-InstallMap
  $members = @(Get-PackModsFull $pack)
  $items = @()
  foreach ($m in $members) {
    $isInstalled = $installed -contains [string]$m.WorkshopId
    $pwid = [string]$m.WorkshopId
    # Installed date (blank when not installed - same rule as Mods tab).
    $pdate = ''
    $psize = [long]0
    if ($isInstalled -and $installMap -and $installMap.PSObject.Properties[$pwid]) {
      $pe = $installMap.PSObject.Properties[$pwid].Value
      $dv = $pe.installed_on
      if ($dv) { $pdate = [string]$dv }
      if ($pe.PSObject.Properties['size'] -and $pe.size) { $psize = [long]$pe.size } else { $psize = Get-ModDiskSize @($pe.folders) }
    }
    $items += [PSCustomObject]@{
      Name = [string]$m.Name
      Category = [string]$m.Cat
      Status = if ($isInstalled) { 'Installed' } else { 'Not installed' }
      InstalledDate = $pdate
      Size = (Format-ModSize $psize)
      SizeBytes = [long]$psize
      WorkshopId = $pwid
      IsChecked = $script:GuiSelectedMods.ContainsKey($pwid)
    }
  }
  $items = Sort-GuiPackMemberRows $items
  $script:GuiPackMemberList.ItemsSource = $items
  # Header sort indicators.
  if ($script:GuiPackMemberList.View -and $script:GuiPackMemberList.View.Columns) {
    $mpvCols = $script:GuiPackMemberList.View.Columns
    $mpl = @('Name', 'Category', 'Status', 'Installed Date', 'Size', 'Workshop ID')
    for ($i = 0; $i -lt 6 -and ($i + 1) -lt $mpvCols.Count; $i++) { $mpvCols[$i + 1].Header = $mpl[$i] }
    $mc = $script:GuiPackMembersSortColumn; $md = $script:GuiPackMembersSortDescending
    if ($mc -eq 'Name') { $mpvCols[1].Header = if ($md) { 'Name (Z-A)' } else { 'Name (A-Z)' } }
    elseif ($mc -eq 'Category') { $mpvCols[2].Header = if ($md) { 'Category (Z-A)' } else { 'Category (A-Z)' } }
    elseif ($mc -eq 'Status') { $mpvCols[3].Header = if ($md) { 'Status (Not installed first)' } else { 'Status (Installed first)' } }
    elseif ($mc -eq 'Date') { $mpvCols[4].Header = if ($md) { 'Installed Date (newest)' } else { 'Installed Date (oldest)' } }
    elseif ($mc -eq 'Size') { $mpvCols[5].Header = if ($md) { 'Size (9-0)' } else { 'Size (0-9)' } }
    elseif ($mc -eq 'WorkshopId') { $mpvCols[6].Header = if ($md) { 'Workshop ID (9-0)' } else { 'Workshop ID (0-9)' } }
  }
  # Detail header select-all checkbox.
  if ($script:GuiPackMemberList.View -and $script:GuiPackMemberList.View.Columns -and $script:GuiPackMemberList.View.Columns.Count -gt 0) {
    $hdrCb = $script:GuiPackMemberList.View.Columns[0].Header
    if ($hdrCb -is [System.Windows.Controls.CheckBox]) {
      $selCount = 0
      foreach ($it in $items) { if ($it.IsChecked) { $selCount++ } }
      if ($items.Count -eq 0 -or $selCount -eq 0) { $hdrCb.IsChecked = $false }
      elseif ($selCount -eq $items.Count) { $hdrCb.IsChecked = $true }
      else { $hdrCb.IsChecked = $false }
    }
  }
  if ($script:GuiPackMemberLabel) { $script:GuiPackMemberLabel.Text = ('Mods in ' + [string]$pack.Name + ' (' + $members.Count + ')') }
  # Rename / Delete only for custom packs; Reset only for copies with a Source.
  $isCustom = [bool]$pack.Custom
  if ($script:GuiPackResetButton) { $script:GuiPackResetButton.Visibility = if ($isCustom -and [string]$pack.Source -ne '') { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed } }
}
function Delete-GuiSelectedPacks {
  # Delete every checked pack. Custom packs are removed; built-in
  # packs are tombstoned for the active list (they stay deleted in
  # this list and still exist in other lists). One confirm.
  if (-not $script:GuiSelectedPacks -or $script:GuiSelectedPacks.Count -eq 0) { Set-GuiTransientStatus ('Select at least one pack first.'); return }
  $names = @($script:GuiSelectedPacks.Keys)
  $all = @(Get-AllPacks)
  $targets = @()
  foreach ($nm in $names) {
    $pk = @($all | Where-Object { [string]$_.Name -eq $nm })[0]
    if ($pk) { $targets += $nm }
  }
  if ($targets.Count -eq 0) { return }
  $res = Show-GuiMessageBox ('Delete ' + $targets.Count + ' selected pack(s) (' + ($targets -join ', ') + ')?') 'PZ Mod Manager' ([System.Windows.MessageBoxButton]::YesNo) ([System.Windows.MessageBoxImage]::Warning)
  if ($res -ne [System.Windows.MessageBoxResult]::Yes) { return }
  $activeList = Get-ActiveListSafe
  $builtinNames = @($Packs | ForEach-Object { [string]$_.Name })
  $customPacks = @(Get-CustomPacks)
  $customPacks = @($customPacks | Where-Object { -not ($targets -contains [string]$_.Name -and [string]$_.List -eq $activeList) })
  Save-CustomPacks $customPacks
  foreach ($nm in $targets) { if ($builtinNames -contains $nm) { Add-RemovedPackName $activeList $nm } }
  if ($targets -contains $script:GuiPackDetailName) { $script:GuiPackDetailName = '' }
  $script:GuiSelectedPacks = @{}
  Set-GuiTransientStatus (('Deleted ' + $targets.Count + ' selected pack(s).'))
  # Standard: refresh every view after this change (one composite call).
  Refresh-GuiAfterListChange
}

function Remove-GuiSelectedPackMembers {
  # Remove every selected member of the detail pack from that pack.
  $detailName = [string]$script:GuiPackDetailName
  if ($detailName -eq '') { Set-GuiTransientStatus ('Select a pack first.'); return }
  $pack = @(Get-AllPacks | Where-Object { $_.Name -eq $detailName })[0]
  if (-not $pack -or -not $pack.Custom) { Set-GuiTransientStatus ('Mods can only be removed from a custom pack. Duplicate a built-in pack first to edit it.'); return }
  $customPacks = @(Get-CustomPacks)
  $activeList = Get-ActiveListSafe
  $target = @($customPacks | Where-Object { $_.Name -eq $detailName -and [string]$_.List -eq $activeList })[0]
  if (-not $target) { return }
  $toRemove = @()
  foreach ($id in @($script:GuiSelectedMods.Keys)) { if (@($target.Ids | Where-Object { [string]$_ -eq $id }).Count -gt 0) { $toRemove += $id } }
  if ($toRemove.Count -eq 0) { Set-GuiTransientStatus ('Select at least one member of this pack to remove.'); return }
  # Safeguard (standard): confirm before removing from the pack.
  $res = Show-GuiMessageBox ('Remove ' + $toRemove.Count + ' selected mod(s) from pack ' + $detailName + '?') 'PZ Mod Manager' ([System.Windows.MessageBoxButton]::YesNo) ([System.Windows.MessageBoxImage]::Warning)
  if ($res -ne [System.Windows.MessageBoxResult]::Yes) { return }
  $target.Ids = @($target.Ids | Where-Object { $toRemove -notcontains [string]$_ })
  Save-CustomPacks $customPacks
  Set-GuiTransientStatus (('Removed ' + $toRemove.Count + ' mod(s) from pack.'))
  # Standard: refresh every view after this change (one composite call).
  Refresh-GuiAfterListChange
}


function Read-GuiInput([string]$prompt, [string]$title, [string]$defaultValue) {
  # Simple text-input dialog (WPF). Returns $null on Cancel or empty.
  # (Was VB InputBox: a system dialog that showed the PowerShell icon
  # and cannot be given an icon. The WPF dialog gets the game icon via
  # the standard.) Enter = OK, Esc = Cancel.
  try {
    Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
    [xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Input" Width="420" Height="170" WindowStartupLocation="CenterScreen" ResizeMode="NoResize">
  <Grid Margin="12">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>
    <TextBlock Grid.Row="0" x:Name="InputPrompt" TextWrapping="Wrap" Margin="0,0,0,8"/>
    <TextBox Grid.Row="1" x:Name="InputBox" Margin="0,0,0,12"/>
    <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right">
      <Button x:Name="InputOk" Content="OK" Padding="16,4" Margin="0,0,8,0" IsDefault="True"/>
      <Button x:Name="InputCancel" Content="Cancel" Padding="16,4" IsCancel="True"/>
    </StackPanel>
  </Grid>
</Window>
'@
    $reader = New-Object System.Xml.XmlNodeReader($xaml)
    $window = [System.Windows.Markup.XamlReader]::Load($reader)
    Add-NoGripperHandler $window
    $window.Title = $title
    $window.FindName('InputPrompt').Text = $prompt
    $window.FindName('InputBox').Text = [string]$defaultValue
    if ($script:GuiWindow) { $window.Owner = $script:GuiWindow }
    Set-DialogWindowIcon $window
    $result = @{ Value = $null }
    $window.FindName('InputOk').Add_Click({ $result.Value = [string]$window.FindName('InputBox').Text; $window.Close() })
    $window.FindName('InputCancel').Add_Click({ $window.Close() })
    $window.Add_Loaded({ $window.FindName('InputBox').Focus() })
    [void]$window.ShowDialog()
    if ([string]$result.Value -eq '') { return $null }
    return $result.Value
  } catch { return $null }
}
function Show-GuiChoiceDialog([string]$title, [string]$question, [string]$choice1, [string]$choice2) {
  # Two-choice dialog (WPF). Returns 1 (first choice), 2 (second choice),
  # or 0 (Cancel / closed). Enter = first choice, Esc = Cancel.
  try {
    Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
    [xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Choose" Width="480" Height="230" WindowStartupLocation="CenterScreen" ResizeMode="NoResize">
  <Grid Margin="12">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>
    <TextBlock Grid.Row="0" x:Name="ChoiceQuestion" TextWrapping="Wrap" Margin="0,0,0,16"/>
    <Button Grid.Row="1" x:Name="Choice1" Padding="16,6" Margin="0,0,0,8" HorizontalAlignment="Stretch" IsDefault="True"/>
    <Button Grid.Row="2" x:Name="Choice2" Padding="16,6" Margin="0,0,0,8" HorizontalAlignment="Stretch"/>
    <Button Grid.Row="3" x:Name="ChoiceCancel" Content="Cancel" Padding="16,6" HorizontalAlignment="Right" IsCancel="True"/>
  </Grid>
</Window>
'@
    $reader = New-Object System.Xml.XmlNodeReader($xaml)
    $window = [System.Windows.Markup.XamlReader]::Load($reader)
    Add-NoGripperHandler $window
    $window.Title = $title
    $window.FindName('ChoiceQuestion').Text = $question
    $window.FindName('Choice1').Content = $choice1
    $window.FindName('Choice2').Content = $choice2
    if ($script:GuiWindow) { $window.Owner = $script:GuiWindow }
    Set-DialogWindowIcon $window
    $result = @{ Value = 0 }
    $window.FindName('Choice1').Add_Click({ $result.Value = 1; $window.Close() })
    $window.FindName('Choice2').Add_Click({ $result.Value = 2; $window.Close() })
    $window.FindName('ChoiceCancel').Add_Click({ $window.Close() })
    [void]$window.ShowDialog()
    return [int]$result.Value
  } catch { return 0 }
}



function Refresh-GuiAfterListChange {
  # Working set or list set changed: refresh every GUI view that reads them.
  # Reload $Mods FIRST: the list file is the source of truth, and a later
  # refresh (CategoriesTab self-heal) used to reload $Mods AFTER the Mods
  # tab had already rendered, leaving a removed mod still visible and the
  # status bar split ('Showing 245 of 244'). Reloading here means every
  # view below renders the same fresh working set.
  $act0 = Get-ActiveListSafe
  if ($act0 -ne '') { [void](Set-ModsFromNamedList $act0) }
  Refresh-GuiCategories
  Refresh-GuiMods
  Refresh-GuiPacks
  Refresh-GuiNamedLists
  Refresh-GuiCategoriesTab
}

function Get-StaleCacheFolders {
  # Shared by Clear-GuiCache: stale SteamCMD download cache + temp
  # folders, and their total size. Returns @{ Folders = @(...); Bytes = n }.
  $cacheRoot = Join-Path (Join-Path (Join-Path $SteamCmdDir 'steamapps') 'workshop') ('content\' + $AppId)
  $stale = @()
  if (Test-Path $cacheRoot) {
    $needed = @{}
    foreach ($m in $Mods) { $needed[[string]$m.WorkshopId] = $true }
    $map = Get-InstallMap
    if ($map) { foreach ($pr in $map.PSObject.Properties) { $needed[[string]$pr.Name] = $true } }
    $stale = @(Get-ChildItem $cacheRoot -Directory | Where-Object { -not $needed.ContainsKey($_.Name) })
  }
  $tmpStale = @(Get-ChildItem ([IO.Path]::GetTempPath()) -Directory -Filter 'pzmod_*' -ErrorAction SilentlyContinue)
  $all = @($stale + $tmpStale)
  $bytes = 0
  foreach ($d in $all) {
    $sz = (Get-ChildItem $d.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    if ($sz) { $bytes += $sz }
  }
  return @{ Folders = $all; Bytes = $bytes }
}

function Clear-GuiCache {
  # GUI Clear cache (was text [9]): confirm, delete, report.
  $info = Get-StaleCacheFolders
  if ($info.Folders.Count -eq 0) { Set-GuiTransientStatus 'Cache is clean - nothing useless found.'; return }
  $mb = [math]::Round($info.Bytes / 1MB, 1)
  $names = @($info.Folders | ForEach-Object { $_.Name })
  $shown = @($names | Select-Object -First 15)
  $list = $shown -join ($NL)
  if ($names.Count -gt 15) { $list += ($NL + '... and ' + ($names.Count - 15) + ' more') }
  $r = Show-GuiMessageBox ('Useless cache: ' + $info.Folders.Count + ' folder(s), ~' + $mb + ' MB.' + $NL + $NL + $list + $NL + $NL + 'Delete them?') 'Clear cache' ([System.Windows.MessageBoxButton]::YesNo) ([System.Windows.MessageBoxImage]::Question)
  if ($r -ne [System.Windows.MessageBoxResult]::Yes) { Set-GuiTransientStatus 'Clear cache cancelled.'; return }
  $n = 0
  foreach ($d in $info.Folders) { Remove-Item $d.FullName -Recurse -Force -ErrorAction SilentlyContinue; $n++ }
  Set-GuiTransientStatus ('Cleaned ' + $n + ' folder(s), freed ~' + $mb + ' MB.')
}

function Get-CompatibilityReport {
  # Compatibility report for the ACTIVE LIST's installed mods.
  # One recursive scan of the mods folder (what the game sees).
  # Verdict per mod: "Incompatible" (blocking reason) or "Compatible".
  # Honest scope: static checks only (version, dependencies, files, encoding).
  # Lua errors, mod conflicts, and load order only show in-game, so
  # "Compatible" means "passes every static check", not a guarantee.
  $rows = @()
  if (-not (Test-Path $ModsDir)) { return $rows }
  $allInfo = @(Get-ChildItem $ModsDir -Recurse -Filter 'mod.info' -File -ErrorAction SilentlyContinue)
  $topToInfos = @{}
  $diskModIds = @{}
  $modIdToInfos = @{}
  foreach ($mi in $allInfo) {
    $rel = $mi.FullName.Substring($ModsDir.Length).TrimStart('\','/')
    $top = ($rel -split '[\\/]')[0]
    if (-not $topToInfos.ContainsKey($top)) { $topToInfos[$top] = @() }
    $topToInfos[$top] += $mi.FullName
    $mid = Get-ModInfoId $mi.FullName
    if ($mid) {
      $diskModIds[$mid] = $true
      if (-not $modIdToInfos.ContainsKey($mid)) { $modIdToInfos[$mid] = @() }
      $modIdToInfos[$mid] += $mi.FullName
    }
  }
  $widToModId = @{}
  foreach ($k in $ModIdToWorkshop.Keys) { $widToModId[[string]$ModIdToWorkshop[$k]] = [string]$k }
  $installMap = Get-InstallMap
  $widToFolders = @{}
  if ($installMap) {
    foreach ($p in $installMap.PSObject.Properties) {
      if ([string]$p.Name -notmatch '^\d+$') { continue }
      if ($p.Value.installed -eq $true -and $p.Value.folders) {
        $widToFolders[[string]$p.Name] = @($p.Value.folders | ForEach-Object { [string]$_ })
      }
    }
  }
  $listWids = @($Mods | ForEach-Object { [string]$_.WorkshopId })
  foreach ($m in $Mods) {
    $wid = [string]$m.WorkshopId
    $name = [string]$m.Name
    # Installed = a recorded folder exists on disk with mod.info (via the
    # one scan above). Fall back to the catalog Mod ID if install-map has
    # no folders for this mod (installed but unrecorded).
    $myInfos = @()
    if ($widToFolders.ContainsKey($wid)) {
      foreach ($f in $widToFolders[$wid]) {
        if ($topToInfos.ContainsKey($f)) { $myInfos += $topToInfos[$f] }
      }
    }
    if ($myInfos.Count -eq 0 -and $widToModId.ContainsKey($wid) -and $modIdToInfos.ContainsKey($widToModId[$wid])) {
      $myInfos = $modIdToInfos[$widToModId[$wid]]
    }
    if ($myInfos.Count -eq 0) { continue }
    $blocked = @(); $notes = @(); $missingDeps = @()
    $multi = ($myInfos.Count -gt 1)
    foreach ($miPath in $myInfos) {
      $raw = ''
      try { $raw = Get-Content $miPath -Raw -ErrorAction Stop } catch { }
      $fid = Get-ModInfoId $miPath
      $prefix = ''
      if ($multi -and $fid) { $prefix = ($fid + ': ') }
      if ($raw -eq '') { $blocked += ($prefix + 'mod.info is empty/unreadable'); continue }
      $utf8Valid = $true
      try {
        $rb = [IO.File]::ReadAllBytes($miPath)
        $dec = [Text.Encoding]::UTF8.GetString($rb)
        if ([Text.Encoding]::UTF8.GetBytes($dec).Length -ne $rb.Length) { $utf8Valid = $false }
      } catch { $utf8Valid = $false }
      if (-not $utf8Valid) { $blocked += ($prefix + 'mod.info has invalid UTF-8 encoding (game may skip it)') }
      $vmin = ''; $vmax = ''
      $mmin = [regex]::Match($raw, '(?m)^\s*versionMin\s*=\s*(.+?)\s*$'); if ($mmin.Success) { $vmin = $mmin.Groups[1].Value.Trim() }
      $mmax = [regex]::Match($raw, '(?m)^\s*versionMax\s*=\s*(.+?)\s*$'); if ($mmax.Success) { $vmax = $mmax.Groups[1].Value.Trim() }
      if ($vmax -match '^\d+$' -and [int]$vmax -lt [int]$GameBuild) { $blocked += ($prefix + "versionMax=$vmax is older than B$GameBuild (game will not load it)") }
      elseif ($vmin -match '^\d+$' -and [int]$vmin -gt [int]$GameBuild) { $blocked += ($prefix + "versionMin=$vmin is newer than B$GameBuild (game will not load it)") }
      elseif ($vmax -match ('^' + $GameBuild + '\.(\d+)$') -and [int]$Matches[1] -lt $GameBuildMinor) { $notes += ($prefix + "versionMax=$vmax caps below $GameBuildFull (may still work)") }
      $mjar = [regex]::Match($raw, '(?m)^\s*javaJarFile\s*=\s*(.+?)\s*$')
      if ($mjar.Success) {
        $jarRel = $mjar.Groups[1].Value.Trim()
        $parentDir = Split-Path $miPath -Parent
        $jarFound = $false
        # Also check the mod ROOT (parent of the mod.info folder): when
        # mod.info sits in a subfolder (e.g. 42/), the JAR lives in the
        # mod root. Missing this caused false "missing file" hits on
        # Viewpoint / Knox Event (both work in-game).
        $modRoot = Split-Path $parentDir -Parent
        $bases = @($parentDir, (Join-Path $parentDir 'common'), (Join-Path $parentDir $GameBuild))
        if ($modRoot) { $bases += $modRoot; $bases += (Join-Path $modRoot 'common'); $bases += (Join-Path $modRoot $GameBuild) }
        foreach ($base in $bases) {
          if (Test-Path (Join-Path $base $jarRel)) { $jarFound = $true; break }
        }
        if (-not $jarFound -and $fid -eq 'ZombieBuddy') {
          $gameJ = Find-GameFolder -AllowPrompt:$false
          if ($gameJ -and (Test-Path (Join-Path $gameJ 'ZombieBuddy.jar'))) { $jarFound = $true }
        }
        if (-not $jarFound) { $blocked += ($prefix + 'references missing file: ' + $jarRel) }
      }
      $reqM = [regex]::Match($raw, '(?m)^\s*require\s*=\s*(.+?)\s*$')
      if ($reqM.Success) {
        $reqIds = @($reqM.Groups[1].Value -split '[,;]' | ForEach-Object { $_.Trim().TrimStart('\') } | Where-Object { $_ -ne '' })
        foreach ($rid in $reqIds) {
          if ($diskModIds.ContainsKey($rid)) { continue }
          if ($missingDeps -notcontains $rid) { $missingDeps += $rid }
          if ($ModIdToWorkshop.ContainsKey($rid)) {
            $dw = [string]$ModIdToWorkshop[$rid]
            if ($listWids -contains $dw) { $blocked += ($prefix + "Missing dependency '$rid' (in list but not installed - install it)") }
            else { $blocked += ($prefix + "Missing dependency '$rid' (Workshop $dw - not in list)") }
          } else {
            $blocked += ($prefix + "Missing dependency '$rid' (unknown Workshop ID - cannot resolve it)")
          }
        }
      }
    }
    $verdict = 'Compatible'
    $details = ''
    if ($blocked.Count -gt 0) {
      $verdict = "Incompatible"
      $details = ($blocked -join '; ')
      if ($notes.Count -gt 0) { $details += ' | ' + ($notes -join '; ') }
    } elseif ($notes.Count -gt 0) {
      $details = ($notes -join '; ')
    } else {
      $details = 'OK'
    }
    $rows += [PSCustomObject]@{ Name = $name; WorkshopId = $wid; Verdict = $verdict; Details = $details; MissingDeps = $missingDeps }
  }
  return $rows
}

function Show-GuiCompatibilityReport($rows) {
  # Read-only compatibility report dialog: Name | Workshop ID | Verdict |
  # Details. No checkboxes (report, not a picker). Search + header-click
  # sort (2-state toggle, like the tabs). Incompatible rows first, then Name.
  if (@($rows).Count -eq 0) { Set-GuiTransientStatus 'Compatibility report: no installed mods in the active list.'; return }
  try {
    Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
    Add-Type -AssemblyName PresentationCore -ErrorAction Stop
    Add-Type -AssemblyName WindowsBase -ErrorAction Stop
    $wont = @($rows | Where-Object { $_.Verdict -eq "Incompatible" }).Count
    $should = $rows.Count - $wont
    $summary = ($should.ToString() + ' compatible, ' + $wont.ToString() + ' incompatible (of ' + $rows.Count.ToString() + ' installed mods in the active list)')
    $sorted = @($rows | Sort-Object @{ Expression = { if ($_.Verdict -eq "Incompatible") { 0 } else { 1 } } }, Name)
    [xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Compatibility report" Width="1020" Height="640" WindowStartupLocation="CenterScreen" ResizeMode="NoResize">
  <Window.Resources>
    <Style x:Key="NoGripperHeader" TargetType="GridViewColumnHeader" BasedOn="{StaticResource {x:Type GridViewColumnHeader}}">
      <Setter Property="Cursor" Value="Arrow"/>
      <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True">
          <Setter Property="Background">
            <Setter.Value>
              <LinearGradientBrush StartPoint="0,0" EndPoint="0,1">
                <GradientStop Color="#E3F7FF" Offset="0"/>
                <GradientStop Color="#BAEAFD" Offset="1"/>
              </LinearGradientBrush>
            </Setter.Value>
          </Setter>
        </Trigger>
      </Style.Triggers>
    </Style>
  </Window.Resources>
  <Grid Margin="10">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>
    <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="0,0,0,6">
      <TextBlock Text="Search:" VerticalAlignment="Center" Margin="0,0,6,0"/>
      <TextBox x:Name="ReportSearchBox" Width="940"/>
    </StackPanel>
    <TextBlock Grid.Row="1" x:Name="ReportSummary" Margin="0,0,0,6"/>
    <TextBlock Grid.Row="2" Text="Static checks only (version, dependencies, files, encoding). Lua errors, mod conflicts, and load order only show in-game." Margin="0,0,0,6" FontStyle="Italic"/>
    <ListView ScrollViewer.HorizontalScrollBarVisibility="Disabled" Grid.Row="3" x:Name="ReportList" SelectionMode="Single">
      <ListView.View><GridView x:Name="ReportGridView" AllowsColumnReorder="False"/></ListView.View>
    </ListView>
    <Border Grid.Row="4" BorderBrush="Gray" BorderThickness="1" Margin="0,8,0,0" MaxHeight="80">
      <TextBox x:Name="ReportDetail" TextWrapping="Wrap" Margin="4" IsReadOnly="True" BorderThickness="0" Background="Transparent" VerticalScrollBarVisibility="Auto" Text="Click a row to read its full details here."/>
    </Border>
    <StackPanel Grid.Row="5" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,8,0,0">
      <Button x:Name="ReportFixDeps" Content="Find And Add Missing Dependencies" Padding="12,4" Margin="0,0,8,0"/>
      <Button x:Name="ReportUninstallWont" Content="Uninstall Incompatible Mods" Padding="12,4" Margin="0,0,8,0"/>
      <Button x:Name="ReportWorkshop" Content="View Mod's Page" Padding="12,4" Margin="0,0,8,0"/>
      <Button x:Name="ReportClose" Content="Close" Padding="12,4"/>
    </StackPanel>
  </Grid>
</Window>
'@
    $reader = New-Object System.Xml.XmlNodeReader($xaml)
    $window = [System.Windows.Markup.XamlReader]::Load($reader)
    Add-NoGripperHandler $window
    $window.FindName('ReportSummary').Text = $summary
    if ($script:GuiWindow) { $window.Owner = $script:GuiWindow }
    Set-DialogWindowIcon $window
    $listView = $window.FindName('ReportList')
    $gridView = $window.FindName('ReportGridView')
    $noGripper = $window.FindResource('NoGripperHeader')
    $cols = @(
      @{ Header = 'Name'; Property = 'Name'; Width = 380 },
      @{ Header = 'Workshop ID'; Property = 'WorkshopId'; Width = 170 },
      @{ Header = 'Details'; Property = 'Details'; Width = 300 },
      @{ Header = 'Verdict'; Property = 'Verdict'; Width = 120 }
    )
    foreach ($col in $cols) {
      $gc = New-Object System.Windows.Controls.GridViewColumn
      $gc.Header = [string]$col.Header
      $gc.Width = [double]$col.Width
      $gc.DisplayMemberBinding = New-Object System.Windows.Data.Binding([string]$col.Property)
      [void]$gridView.Columns.Add($gc)
    }
    $gridView.Columns[$gridView.Columns.Count - 1].HeaderContainerStyle = $noGripper
    Register-LastColumnFill $listView
    $state = @{ SortProp = ''; SortDesc = $false; Query = '' }
    $refresh = {
      $shown = @($sorted)
      if ($state.SortProp -ne '') {
        if ($state.SortDesc) { $shown = @($shown | Sort-Object $state.SortProp -Descending) } else { $shown = @($shown | Sort-Object $state.SortProp) }
      }
      if ($state.Query -ne '') {
        $q = $state.Query.ToLower()
        $shown = @($shown | Where-Object { ([string]$_.Name).ToLower().Contains($q) -or ([string]$_.WorkshopId).ToLower().Contains($q) -or ([string]$_.Verdict).ToLower().Contains($q) -or ([string]$_.Details).ToLower().Contains($q) })
      }
      $listView.ItemsSource = $shown
    }
    $listView.AddHandler([System.Windows.Controls.GridViewColumnHeader]::ClickEvent, [System.Windows.RoutedEventHandler]{
      param($sender, $e)
      $hdr = $e.OriginalSource -as [System.Windows.Controls.GridViewColumnHeader]
      $bind = $null
      if ($hdr -and $hdr.Column) { $bind = $hdr.Column.DisplayMemberBinding }
      if ($bind -and $bind.Path -and $bind.Path.Path) {
        $prop = [string]$bind.Path.Path
        if ($state.SortProp -eq $prop) { $state.SortDesc = -not $state.SortDesc } else { $state.SortProp = $prop; $state.SortDesc = $false }
        & $refresh
      }
    })
    $listView.Add_SelectionChanged({
      $sel = $listView.SelectedItem
      $txt = 'Click a row to read its full details here.'
      if ($sel -and [string]$sel.Details -ne '') { $txt = [string]$sel.Details }
      $window.FindName('ReportDetail').Text = $txt
      # Standard: View this mod on Workshop needs a highlighted row
      # with a numeric Workshop ID whose Name is not just the ID.
      $window.FindName('ReportWorkshop').IsEnabled = ($null -ne $sel -and [string]$sel.WorkshopId -match '^\d+$' -and [string]$sel.Name -ne '' -and [string]$sel.Name -ne [string]$sel.WorkshopId)
    })
    $window.FindName('ReportSearchBox').Add_TextChanged({ $state.Query = [string]$window.FindName('ReportSearchBox').Text; & $refresh })
    $window.FindName('ReportFixDeps').Add_Click({
      # Find + add missing dependencies. Verified vs unverified vs stale:
      # - KNOWN dependency (in $ModIdToWorkshop): added directly - the map
      #   entry is the Mod ID verification.
      # - UNKNOWN dep: Workshop-searched by title. A title match does
      #   NOT prove the Mod ID matches, so picked results are added
      #   as UNVERIFIED (re-run the report after installing to
      #   confirm the Mod ID). The picker says so.
      # - STALE dep: no map entry AND the search returned zero results
      #   with no search error - the Mod ID is likely renamed/dead.
      #   Never added; reported so the user removes the patch mod
      #   instead of installing more (the old code silently skipped
      #   these, which is why it felt like a never-ending cycle).
      $depIds = @()
      foreach ($r in $rows) { foreach ($d in @($r.MissingDeps)) { if ($depIds -notcontains $d) { $depIds += $d } } }
      if ($depIds.Count -eq 0) { Set-GuiTransientStatus 'No missing dependencies in this report.'; return }
      $verified = @()
      $unknown = @()
      foreach ($d in $depIds) {
        if ($ModIdToWorkshop.ContainsKey($d)) { $verified += [PSCustomObject]@{ WorkshopId = [string]$ModIdToWorkshop[$d]; Name = $d } }
        else { $unknown += $d }
      }
      $unverified = @()
      $stale = @()
      $searchErrors = @()
      if ($unknown.Count -gt 0) {
        $candidates = @()
        foreach ($d in $unknown) {
          $found = @(Search-WorkshopMods $d)
          if ($found.Count -eq 0) {
            if ([string]$script:LastWorkshopSearchError -ne '') { $searchErrors += ($d + ': ' + [string]$script:LastWorkshopSearchError) }
            else { $stale += $d }
            continue
          }
          foreach ($f in $found) { $candidates += [PSCustomObject]@{ Name = [string]$f.Name; WorkshopId = [string]$f.WorkshopId; Cat = ''; Status = ''; Details = ('Search result for ' + $d + ' - Mod ID NOT confirmed') } }
        }
        if ($candidates.Count -gt 0) {
          $res = Show-GuiWpfPicker 'Missing dependencies' 'Select the Workshop items to add (title matches only - the Mod ID is NOT confirmed. Only select a result if you are sure it is the right mod):' $candidates @(@{ Header = 'Name'; Property = 'Name'; Width = 620 }, @{ Header = 'Workshop ID'; Property = 'WorkshopId'; Width = 300 }) 'Add Selected'
          if ($res.Failed) { Set-GuiTransientStatus ('Could not open the picker: ' + [string]$script:LastPickerError); return }
          foreach ($sel in @($res.Selected)) { $unverified += [PSCustomObject]@{ WorkshopId = [string]$sel.WorkshopId; Name = [string]$sel.Name } }
        }
      }
      $added = @($verified) + @($unverified)
      if ($added.Count -gt 0) {
        $activeSafe = Get-ActiveListSafe
        if ($activeSafe -eq '') { Set-GuiTransientStatus 'No active list.'; return }
        Add-GuiListMembers $activeSafe $added
      }
      $msg = ''
      if ($verified.Count -gt 0) { $msg += ('Added ' + $verified.Count.ToString() + ' verified dep(s) (Mod ID map). ') }
      if ($unverified.Count -gt 0) { $msg += ('Added ' + $unverified.Count.ToString() + ' UNVERIFIED dep(s) (title match only - re-run Compatibility report after installing to confirm the Mod ID). ') }
      if ($stale.Count -gt 0) { $msg += ('Stale dep(s) with no Workshop match (Mod ID may be renamed/dead - remove the patch mod instead of installing more): ' + ($stale -join ', ') + '. ') }
      if ($searchErrors.Count -gt 0) { $msg += ('Search failed for: ' + ($searchErrors -join '; ') + '. ') }
      if ($msg -eq '') { $msg = 'No dependencies to add (none found).' }
      Set-GuiTransientStatus $msg
      $window.Close()
    })
    $window.FindName('ReportUninstallWont').Add_Click({
      # Uninstall the incompatible mods: picker (all selected), confirm,
      # then remove each from disk (Remove-WorkshopId) AND from the
      # active list. Uninstalling a mod may break other mods that
      # depend on it - the picker says so, and unticking keeps it.
      $wontRows = @($rows | Where-Object { $_.Verdict -eq "Incompatible" })
      if ($wontRows.Count -eq 0) { Set-GuiTransientStatus 'No incompatible mods in this report.'; return }
      $candidates = @()
      foreach ($r in $wontRows) { $candidates += [PSCustomObject]@{ Name = [string]$r.Name; WorkshopId = [string]$r.WorkshopId; Cat = ''; Status = ''; Details = [string]$r.Details } }
      $res = Show-GuiWpfPicker 'Uninstall incompatible mods' 'Select the incompatible mods to uninstall (removes them from the active list and deletes their folders). Uninstalling a mod may break other mods that depend on it:' $candidates @(@{ Header = 'Name'; Property = 'Name'; Width = 500 }, @{ Header = 'Workshop ID'; Property = 'WorkshopId'; Width = 200 }, @{ Header = 'Details'; Property = 'Details'; Width = 300 }) 'Uninstall Selected'
      if ($res.Failed) { Set-GuiTransientStatus ('Could not open the picker: ' + [string]$script:LastPickerError); return }
      $picked = @($res.Selected)
      if ($picked.Count -eq 0) { Set-GuiTransientStatus 'Uninstall cancelled.'; return }
      $confirm = Show-GuiMessageBox ('Uninstall ' + $picked.Count + ' won''t-work mod(s)? This removes them from the active list and deletes their folders.') 'PZ Mod Manager' ([System.Windows.MessageBoxButton]::YesNo) ([System.Windows.MessageBoxImage]::Warning)
      if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) { return }
      $activeSafe = Get-ActiveListSafe
      if ($activeSafe -eq '') { Set-GuiTransientStatus 'No active list.'; return }
      $d = Get-NamedListData $activeSafe
      if ($d) {
        $ids = @($picked | ForEach-Object { [string]$_.WorkshopId })
        $listMods = @(@($d.mods) | Where-Object { $ids -notcontains [string]$_.workshopId })
        Save-NamedListData $activeSafe $d.name $listMods
      }
      foreach ($p in $picked) { [void](Remove-WorkshopId ([string]$p.WorkshopId)) }
      Set-GuiTransientStatus ('Uninstalled ' + $picked.Count + ' won''t-work mod(s). Re-run Compatibility report to verify.')
      Refresh-GuiAfterListChange
      $window.Close()
    })
    # Standard: View this mod on Workshop starts disabled (no row selected).
    $window.FindName('ReportWorkshop').IsEnabled = $false
    $window.FindName('ReportWorkshop').Add_Click({ param($sender, $e); $w = [System.Windows.Window]::GetWindow($sender); if (-not $w) { return }; $lv = $w.FindName('ReportList'); if (-not $lv) { return }; $sel = $lv.SelectedItem; if ($sel -and [string]$sel.WorkshopId -match '^\d+$' -and [string]$sel.Name -ne '' -and [string]$sel.Name -ne [string]$sel.WorkshopId) { Start-Process ('https://steamcommunity.com/sharedfiles/filedetails/?id=' + [string]$sel.WorkshopId) } })
    $window.FindName('ReportClose').Add_Click({ $window.Close() })
    & $refresh
    [void]$window.ShowDialog()
  } catch {
    Set-GuiTransientStatus ('Compatibility report failed: ' + $_.Exception.Message)
  }
}

function Show-GuiCompatibilityReportDialog {
  # Mods tab: Compatibility report. Scans the active list's installed
  # mods, shows the read-only verdict dialog, and posts the counts.
  Set-GuiBusy $true
  try {
    $rows = @(Get-CompatibilityReport)
    if ($rows.Count -eq 0) { Set-GuiTransientStatus 'Compatibility report: no installed mods in the active list.'; return }
    Show-GuiCompatibilityReport $rows
    $wont = @($rows | Where-Object { $_.Verdict -eq "Incompatible" }).Count
    Set-GuiTransientStatus ('Compatibility report: ' + ($rows.Count - $wont).ToString() + ' compatible, ' + $wont.ToString() + ' incompatible.')
  } finally { Set-GuiBusy $false }
}

function Search-WorkshopMods([string]$query, [int]$MaxResults = 30) {
  # Search the Steam Workshop by keyword (no Steam API for search, so
  # this reads the Workshop browse page). The page embeds structured
  # JSON with publishedfileid + title per result - parsed with a
  # regex anchored to short_description (a bare title capture is too
  # greedy across the JSON). Returns rows: WorkshopId / Name.
  # -MaxResults (default 30) paginates the browse (p=1, p=2, ...) until
  # that many unique results are collected or the pages run dry.
  # Results are ranked by Steam's relevance, NOT by subscriptions -
  # Steam exposes no subscription-ranked list.
  # On failure (network, Steam block, CAPTCHA) returns @() and sets
  # $script:LastWorkshopSearchError. Never throws.
  $script:LastWorkshopSearchError = ''
  $query = $query.Trim()
  if ($query -eq '') { return @() }
  if ($MaxResults -lt 1) { $MaxResults = 30 }
  $pat = 'publishedfileid\\":\\"(\d+)\\".{0,1500}?title\\":\\"((?:[^\\]|\\.)*?)\\",\\"short_description'
  $seen = @{}
  $rows = @()
  $page = 1
  while ($rows.Count -lt $MaxResults -and $page -le 10) {
    try {
      $url = 'https://steamcommunity.com/workshop/browse/?appid=108600&searchtext=' + [uri]::EscapeDataString($query) + '&browsesort=textsearch&section=readytouseitems&p=' + $page
      $resp = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop
      $html = [string]$resp.Content
    } catch {
      $script:LastWorkshopSearchError = $_.Exception.Message
      break
    }
    if ($html -match 'captcha' -or $html -match 'Please verify') {
      $script:LastWorkshopSearchError = 'Steam asked for verification (CAPTCHA).'
      break
    }
    $matches = [regex]::Matches($html, $pat)
    if ($matches.Count -eq 0) { break }
    $newOnPage = 0
    foreach ($x in $matches) {
      $id = $x.Groups[1].Value
      if ($seen.ContainsKey($id)) { continue }
      $seen[$id] = $true
      $t = $x.Groups[2].Value -replace '\\"', '"'
      $t = [System.Net.WebUtility]::HtmlDecode($t)
      $rows += [PSCustomObject]@{ WorkshopId = $id; Name = $t }
      $newOnPage++
    }
    if ($newOnPage -eq 0) { break }
    $page++
  }
  if ($rows.Count -gt $MaxResults) { $rows = @($rows | Select-Object -First $MaxResults) }
  return $rows
}

function Show-GuiWorkshopSearch {
  # Workshop Search dialog: keyword -> Search -> tick results -> Add
  # selected. Same ListView + GridView pattern as the pickers. Returns
  # @{ Selected; Failed } where Selected = @{ WorkshopId; Name } rows.
  # The caller adds them to the list (Add-GuiListMembers).
  try {
    Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
    Add-Type -AssemblyName PresentationCore -ErrorAction Stop
    Add-Type -AssemblyName WindowsBase -ErrorAction Stop
    [xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Search Workshop" Width="1020" Height="640" WindowStartupLocation="CenterScreen" ResizeMode="NoResize">
  <Window.Resources>
    <Style x:Key="NoGripperHeader" TargetType="GridViewColumnHeader" BasedOn="{StaticResource {x:Type GridViewColumnHeader}}">
      <Setter Property="Cursor" Value="Arrow"/>
      <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True">
          <Setter Property="Background">
            <Setter.Value>
              <LinearGradientBrush StartPoint="0,0" EndPoint="0,1">
                <GradientStop Color="#E3F7FF" Offset="0"/>
                <GradientStop Color="#BAEAFD" Offset="1"/>
              </LinearGradientBrush>
            </Setter.Value>
          </Setter>
        </Trigger>
      </Style.Triggers>
    </Style>
  </Window.Resources>
  <Grid Margin="10">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>
    <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="0,0,0,6">
      <TextBlock Text="Search:" VerticalAlignment="Center" Margin="0,0,6,0"/>
      <TextBox x:Name="SearchBox" Width="760"/>
      <Button x:Name="SearchGo" Content="Search" Padding="12,4" Margin="8,0,0,0"/>
      <Button x:Name="SearchBrowsePopular" Content="Browse Popular" Padding="12,4" Margin="8,0,0,0"/>
    </StackPanel>
    <TextBlock Grid.Row="1" x:Name="SearchInstruction" Text="Type a keyword, click Search, tick the mods to add. Browse Popular fetches up to 100 B42 mods (ranked by relevance, not subscriptions)." Margin="0,0,0,6"/>
    <ListView ScrollViewer.HorizontalScrollBarVisibility="Disabled" Grid.Row="2" x:Name="SearchList" SelectionMode="Single">
      <ListView.View><GridView x:Name="SearchGridView" AllowsColumnReorder="False"/></ListView.View>
    </ListView>
    <StackPanel Grid.Row="3" Orientation="Horizontal" Margin="0,8,0,0">
      <Button x:Name="SearchWorkshop" Content="View Mod's Page" Padding="12,4" Margin="0,0,8,0"/>
      <Button x:Name="SearchAdd" Content="Add Selected (0)" Padding="12,4" Margin="590,0,8,0" IsEnabled="False"/>
      <Button x:Name="SearchCancel" Content="Cancel" Padding="12,4"/>
    </StackPanel>
  </Grid>
</Window>
'@
    $reader = New-Object System.Xml.XmlNodeReader($xaml)
    $window = [System.Windows.Markup.XamlReader]::Load($reader)
    Add-NoGripperHandler $window
    if ($script:GuiWindow) { $window.Owner = $script:GuiWindow }
    Set-DialogWindowIcon $window
    $listView = $window.FindName('SearchList')
    $gridView = $window.FindName('SearchGridView')
    $checkTpl = [System.Windows.Markup.XamlReader]::Parse('<DataTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"><CheckBox IsChecked="{Binding IsChecked}" HorizontalAlignment="Center" VerticalAlignment="Center"/></DataTemplate>')
    Build-StandardGridColumns $gridView @(
      @{ Header = 'Name'; Property = 'Name'; Width = 560 },
      @{ Header = 'Workshop ID'; Property = 'WorkshopId'; Width = 280 }
    ) $checkTpl $window.FindResource('NoGripperHeader')
    Register-LastColumnFill $listView
    # Standard (same as the main tabs): header Select All checkbox +
    # selection-gated Add Selected button with a count.
    $hdrCheck = New-Object System.Windows.Controls.CheckBox
    $hdrCheck.Tag = 'SelectAll'
    $hdrCheck.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $hdrCheck.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $gridView.Columns[0].Header = $hdrCheck
    $state = @{ Rows = @(); SortProp = ''; SortDesc = $false }
    $refresh = {
      $shown = @($state.Rows)
      if ($state.SortProp -ne '') {
        if ($state.SortDesc) { $shown = @($shown | Sort-Object $state.SortProp -Descending) } else { $shown = @($shown | Sort-Object $state.SortProp) }
      }
      $listView.ItemsSource = $shown
      $nChecked = @($state.Rows | Where-Object { [bool]$_.IsChecked }).Count
      $window.FindName('SearchAdd').IsEnabled = ($nChecked -gt 0)
      $window.FindName('SearchAdd').Content = ('Add Selected (' + $nChecked + ')')
      $hdrCheck.IsChecked = (@($state.Rows).Count -gt 0 -and $nChecked -eq @($state.Rows).Count)
    }
    $listView.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, [System.Windows.RoutedEventHandler]{
      param($sender, $e)
      $cb = $e.OriginalSource -as [System.Windows.Controls.CheckBox]
      if ($cb -and [string]$cb.Tag -eq 'SelectAll') {
        $allChecked = (@($state.Rows).Count -gt 0 -and @($state.Rows | Where-Object { [bool]$_.IsChecked }).Count -eq @($state.Rows).Count)
        foreach ($r in $state.Rows) { $r.IsChecked = (-not $allChecked) }
        & $refresh
      } elseif ($cb -and $cb.DataContext) { $cb.DataContext.IsChecked = [bool]$cb.IsChecked; & $refresh }
    })
    $listView.AddHandler([System.Windows.Controls.GridViewColumnHeader]::ClickEvent, [System.Windows.RoutedEventHandler]{
      param($sender, $e)
      $hdr = $e.OriginalSource -as [System.Windows.Controls.GridViewColumnHeader]
      $bind = $null
      if ($hdr -and $hdr.Column) { $bind = $hdr.Column.DisplayMemberBinding }
      if ($bind -and $bind.Path -and $bind.Path.Path) {
        $prop = [string]$bind.Path.Path
        if ($state.SortProp -eq $prop) { $state.SortDesc = -not $state.SortDesc } else { $state.SortProp = $prop; $state.SortDesc = $false }
        & $refresh
      }
    })
    $listView.Add_SelectionChanged({
      # Standard: View this mod on Workshop needs a highlighted row
      # with a numeric Workshop ID whose Name is not just the ID.
      $selS = $listView.SelectedItem
      $window.FindName('SearchWorkshop').IsEnabled = ($null -ne $selS -and [string]$selS.WorkshopId -match '^\d+$' -and [string]$selS.Name -ne '' -and [string]$selS.Name -ne [string]$selS.WorkshopId)
    })
    # Standard: View this mod on Workshop starts disabled (no row selected).
    $window.FindName('SearchWorkshop').IsEnabled = $false
    $doSearch = {
      $q = [string]$window.FindName('SearchBox').Text
      if ($q.Trim() -eq '') { $window.FindName('SearchInstruction').Text = 'Type a keyword first.'; return }
      $window.FindName('SearchInstruction').Text = ('Searching Workshop for "' + $q.Trim() + '"...')
      $found = @(Search-WorkshopMods $q)
      if ($found.Count -eq 0) {
        if ($script:LastWorkshopSearchError) { $window.FindName('SearchInstruction').Text = ('Search failed: ' + $script:LastWorkshopSearchError + ' - paste the ID/URL instead.') }
        else { $window.FindName('SearchInstruction').Text = ('No results for "' + $q.Trim() + '".') }
        $state.Rows = @()
      } else {
        $state.Rows = @($found | ForEach-Object {
          [PSCustomObject]@{ IsChecked = $true; Name = [string]$_.Name; WorkshopId = [string]$_.WorkshopId }
        })
        $window.FindName('SearchInstruction').Text = ('Found ' + $found.Count.ToString() + ' result(s) - tick the mods to add.')
      }
      & $refresh
    }
    $window.FindName('SearchGo').Add_Click($doSearch)
    $doBrowsePopular = {
      $window.FindName('SearchInstruction').Text = 'Fetching popular B42 mods (up to 100)...'
      $found = @(Search-WorkshopMods 'B42' -MaxResults 100)
      if ($found.Count -eq 0) {
        if ($script:LastWorkshopSearchError) { $window.FindName('SearchInstruction').Text = ('Browse failed: ' + $script:LastWorkshopSearchError + ' - paste the ID/URL instead.') }
        else { $window.FindName('SearchInstruction').Text = 'No popular mods found.' }
        $state.Rows = @()
      } else {
        $state.Rows = @($found | ForEach-Object {
          [PSCustomObject]@{ IsChecked = $true; Name = [string]$_.Name; WorkshopId = [string]$_.WorkshopId }
        })
        $window.FindName('SearchInstruction').Text = ('Found ' + $found.Count.ToString() + ' popular mod(s) - tick the mods to add. (Ranked by relevance, not subscriptions.)')
      }
      & $refresh
    }
    $window.FindName('SearchBrowsePopular').Add_Click($doBrowsePopular)
    $window.FindName('SearchBox').Add_KeyDown({ param($s2, $e2); if ($e2.Key -eq [System.Windows.Input.Key]::Enter) { & $doSearch } })
    $result = @{ Selected = $null }
    $window.FindName('SearchAdd').Add_Click({
      $sel = @()
      foreach ($r in $state.Rows) { if ([bool]$r.IsChecked) { $sel += [PSCustomObject]@{ WorkshopId = [string]$r.WorkshopId; Name = [string]$r.Name } } }
      $result.Selected = $sel
      $window.Close()
    })
    $window.FindName('SearchWorkshop').Add_Click({ param($sender, $e); $w = [System.Windows.Window]::GetWindow($sender); if (-not $w) { return }; $lv = $w.FindName('SearchList'); if (-not $lv) { return }; $sel = $lv.SelectedItem; if ($sel -and [string]$sel.WorkshopId -match '^\d+$' -and [string]$sel.Name -ne '' -and [string]$sel.Name -ne [string]$sel.WorkshopId) { Start-Process ('https://steamcommunity.com/sharedfiles/filedetails/?id=' + [string]$sel.WorkshopId) } })
    $window.FindName('SearchCancel').Add_Click({ $window.Close() })
    & $refresh
    [void]$window.ShowDialog()
    if ($result.Selected -eq $null -or @($result.Selected).Count -eq 0) { return [PSCustomObject]@{ Selected = @(); Failed = $false } }
    return [PSCustomObject]@{ Selected = $result.Selected; Failed = $false }
  } catch {
    $script:LastPickerError = $_.Exception.Message + ' || STACK: ' + [string]$_.ScriptStackTrace
    return [PSCustomObject]@{ Selected = @(); Failed = $true }
  }
}

function Remove-GuiSelectedModsFromList {
  # Mods tab: remove every selected mod (shared selection) from the ACTIVE list.
  $activeSafe = Get-ActiveListSafe
  if ($activeSafe -eq '') { Set-GuiTransientStatus ('No active list.'); return }
  $d = Get-NamedListData $activeSafe
  if (-not $d) { return }
  $listMods = @($d.mods)
  $toRemove = @()
  foreach ($id in @($script:GuiSelectedMods.Keys)) { if (@($listMods | Where-Object { [string]$_.workshopId -eq $id }).Count -gt 0) { $toRemove += $id } }
  if ($toRemove.Count -eq 0) { Set-GuiTransientStatus ('Select at least one mod to remove.'); return }
  # Safeguard: removal from the list is destructive (category assignments
  # are lost) and the button sits next to frequent actions, so confirm.
  $res = Show-GuiMessageBox ('Remove ' + $toRemove.Count + ' selected mod(s) from list ' + [string]$d.name + '? (The mods stay installed on disk.)') 'PZ Mod Manager' ([System.Windows.MessageBoxButton]::YesNo) ([System.Windows.MessageBoxImage]::Warning)
  if ($res -ne [System.Windows.MessageBoxResult]::Yes) { return }
  $listMods = @($listMods | Where-Object { $toRemove -notcontains [string]$_.workshopId })
  Save-NamedListData $activeSafe $d.name $listMods
  foreach ($id in $toRemove) { $script:GuiSelectedMods.Remove($id) }
  Set-GuiTransientStatus (('Removed ' + $toRemove.Count + ' mod(s) from list.'))
  Refresh-GuiAfterListChange
}

function Find-GuiHeaderCheckbox($listView, $tag) {
  # One-time visual tree walk to locate a header checkbox. Result is cached
  # in $script:GuiHeaderCheckboxes; Sync uses the cache (no walk per click).
  if (-not $listView) { return $null }
  try {
    $queue = New-Object System.Collections.Generic.Queue[System.Windows.DependencyObject]
    $queue.Enqueue($listView)
    while ($queue.Count -gt 0) {
      $obj = $queue.Dequeue()
      if ($obj -is [System.Windows.Controls.CheckBox] -and [string]$obj.Tag -eq $tag) { return $obj }
      if ($obj -is [System.Windows.Media.Visual]) {
        $n = [System.Windows.Media.VisualTreeHelper]::GetChildrenCount($obj)
        for ($i = 0; $i -lt $n; $i++) { $queue.Enqueue([System.Windows.Media.VisualTreeHelper]::GetChild($obj, $i)) }
      }
    }
  } catch { }
  return $null
}
function Sync-GuiHeaderCheckbox($listView, $tag, $shownIds, $selected) {
  # Standard: the header Select-All checkbox must always reflect reality.
  # Checked only when at least one row is shown AND every shown row is selected.
  # Uses a cached checkbox reference (populated once per ListView); the tree
  # walk only runs on first use, not on every click.
  try {
    if (-not $script:GuiHeaderCheckboxes) { $script:GuiHeaderCheckboxes = @{} }
    $cb = $script:GuiHeaderCheckboxes[$tag]
    if (-not $cb) {
      $cb = Find-GuiHeaderCheckbox $listView $tag
      if ($cb) { $script:GuiHeaderCheckboxes[$tag] = $cb }
    }
    if ($cb) {
      $all = $false
      if ($shownIds -and $shownIds.Count -gt 0 -and $selected) {
        $all = $true
        foreach ($k in @($shownIds.Keys)) { if (-not $selected.ContainsKey($k)) { $all = $false; break } }
      }
      $cb.IsChecked = $all
    }
  } catch { }
}

function New-GuiDebounce($milliseconds, [scriptblock]$action) {
  # Returns a scriptblock that delays $action until $milliseconds pass with
  # no new calls. Standard for search-as-you-type: avoids a full refresh
  # (list rebuild + sort + stats) on every keystroke.
  $timer = New-Object System.Windows.Threading.DispatcherTimer
  $timer.Interval = [TimeSpan]::FromMilliseconds($milliseconds)
  # The tick handler MUST capture $timer/$action (GetNewClosure):
  # without it $timer is $null when the tick fires (the function has
  # returned), and $timer.Stop() throws 'method on a null-valued
  # expression' - the v424 search crash.
  $timer.Add_Tick(({ $timer.Stop(); & $action }).GetNewClosure())
  return { param() $timer.Stop(); $timer.Start() }.GetNewClosure()
}

function Clear-GuiSelection {
  # Standard: every tab's checkbox selection resets whenever any visible list
  # changes (any filter/search) or after a bulk action (install/uninstall).
  $script:GuiSelectedMods = @{}
  $script:GuiSelectedPacks = @{}
  $script:GuiSelectedLists = @{}
  $script:GuiSelectedCategories = @{}
  Update-GuiSelectionButtons
  Update-GuiPackSelectionButtons
  Update-GuiListSelectionButtons
  Update-GuiCategorySelectionButtons
}

function Install-GuiSelectedMods {
  Clear-DiskModIdMap
  $script:AbortVariantBatch = $false
  $script:BatchVariantDecisions = $true
  $script:PendingVariantDecisions = @()
  $script:BatchPreCheckDecisions = $true
  $script:PendingPreCheckFailures = @()
  # Install every checked mod in the Mods tab (Install selected). Selection
  # is cleared after install and on filter changes (see Clear-GuiSelection).
  # Mods already installed are skipped by Install-Mod ('make sure it is there').
  # Two-phase variant handling: the first pass installs single-variant
  # mods and DEFERS multi-variant mods (their decisions are collected,
  # no popup per mod). Then ONE consolidated picker decides all
  # deferred mods at once, and the complete phase installs them.
  if (-not $script:GuiSelectedMods -or $script:GuiSelectedMods.Count -eq 0) { Set-GuiTransientStatus ('Select at least one mod first.'); $script:BatchVariantDecisions = $false; $script:BatchPreCheckDecisions = $false; return }
  Set-GuiBusy $true
  try {
  $ids = @($script:GuiSelectedMods.Keys)
  $script:GuiStatusText.Text = ('Installing ' + $ids.Count + ' selected mods... (please wait)')
  $script:GuiWindow.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Render, [System.Action]{})
  $ok = 0
  $start = Get-Date
  $n = 0
  $inMods = @{}
  foreach ($m in @($Mods | Where-Object { $ids -contains [string]$_.WorkshopId })) {
    $inMods[[string]$m.WorkshopId] = $true
    $n++; Show-GuiInstallProgress $n $ids.Count $m.Name $start 'Installing'
    $r = Install-Mod $m.WorkshopId $m.Name
    if ($r -eq $true) { $ok++ }
    if ($script:AbortVariantBatch) { break }
  }
  # Selected mods not in the current working set (checked in another list view)
  # still install, using the stored name.
  foreach ($id in $ids) {
    if ($script:AbortVariantBatch) { break }
    if (-not $inMods.ContainsKey($id)) { $n++; Show-GuiInstallProgress $n $ids.Count $script:GuiSelectedMods[$id] $start 'Installing'; $r2 = Install-Mod $id $script:GuiSelectedMods[$id]; if ($r2 -eq $true) { $ok++ } }
  }
  # Consolidated picker: decide ALL deferred multi-variant mods at once.
  # Batch mode is OFF for the complete phase (its dependency installs
  # use the per-mod picker, not another defer).
  $script:BatchVariantDecisions = $false
  $pending = @($script:PendingVariantDecisions | Where-Object { [string]$_.Kind -eq 'Install' })
  if ($pending.Count -gt 0 -and -not $script:AbortVariantBatch) {
    $script:GuiStatusText.Text = ('Deciding versions for ' + $pending.Count + ' mod(s)...')
    $script:GuiWindow.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Render, [System.Action]{})
    $conRes = Show-GuiConsolidatedVariantPicker $pending
    if ($conRes.CancelAll) {
      $script:AbortVariantBatch = $true
    } elseif ($conRes.Decisions) {
      foreach ($pd in $pending) {
        if ($script:AbortVariantBatch) { break }
        $dec = $conRes.Decisions[[string]$pd.WorkshopId]
        if (-not $dec) { $dec = @{ KeptIndices = @(0..(@($pd.VariantDirs).Count - 1)); KeptIds = @($pd.Candidates | ForEach-Object { [string]$_.WorkshopId }) } }
        if ((Complete-DeferredInstall $pd $dec) -eq $true) { $ok++ }
      }
    }
  }
  # Consolidated pre-install check: ONE list for all mods that failed
  # the pre-install check (instead of a popup per mod). Batch mode is
  # OFF for the complete phase (its dependency installs use the
  # per-mod popup, not another defer).
  $script:BatchPreCheckDecisions = $false
  $preFailed = @($script:PendingPreCheckFailures)
  if ($preFailed.Count -gt 0 -and -not $script:AbortVariantBatch) {
    $script:GuiStatusText.Text = ('Deciding pre-install check failures for ' + $preFailed.Count + ' mod(s)...')
    $script:GuiWindow.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Render, [System.Action]{})
    $pcCands = @()
    foreach ($pf in $preFailed) {
      $pfDetails = ($pf.Reasons -join "`n")
      if (@($pf.WillInstallDeps).Count -gt 0) { $pfDetails += "`n`nWill also install (dependencies): " + ($pf.WillInstallDeps -join ", ") }
      $pcCands += [PSCustomObject]@{ Name = [string]$pf.Name; WorkshopId = [string]$pf.WorkshopId; Cat = ''; Status = (($pf.Reasons -join '; ')); Details = $pfDetails; IsChecked = $false }
    }
    $pcCols = @( @{ Header='Name'; Property='Name'; Width=400 }, @{ Header='Workshop ID'; Property='WorkshopId'; Width=150 }, @{ Header='Reasons'; Property='Status'; Width=400 } )
    $pcRes = Show-GuiWpfPicker 'Pre-Install Compatibility Check' 'The following mods failed the pre-install compatibility check. Select the ones to install anyway (the rest will stay out of the game folder).' $pcCands $pcCols 'Install Selected'
    if (-not $pcRes.Failed -and $pcRes.Selected) {
      foreach ($sel in @($pcRes.Selected)) {
        $pf = @($preFailed | Where-Object { [string]$_.WorkshopId -eq [string]$sel.WorkshopId })[0]
        if ($pf -and (Complete-InstallModCore [string]$pf.WorkshopId [string]$pf.Name @($pf.KeptDirs) @($pf.CarryVariants) @($pf.DroppedIds) $pf.Prop0 [string]$pf.Src -SkipPreCheck) -eq $true) { $ok++ }
      }
    }
  }
  if ($script:AbortVariantBatch) { Set-GuiTransientStatus ('Installation cancelled.') } else { Set-GuiTransientStatus ('Done: ' + $ok + '/' + $ids.Count + ' selected mods installed.') }
  Clear-GuiSelection
  # Standard: refresh every view after install (one composite call).
  Refresh-GuiAfterListChange
  } finally { Set-GuiBusy $false; $script:BatchVariantDecisions = $false; $script:BatchPreCheckDecisions = $false }
}

function Apply-ManageVariantDecision($prop, $folders, $keptDirs, $carryVariants, $droppedIds, $storedV) {
  # Apply a Manage-variants decision: delete dropped variant folders
  # (scoped to this mod's recorded folders, matched by Mod ID),
  # update the map entry (folders + variants). Returns
  # @{ Changed; RemovedFolders }. Shared by the immediate path
  # (no decision needed) and the consolidated-picker path.
  $removed = 0
  if (@($droppedIds).Count -gt 0) {
    foreach ($ef in $folders) {
      $eMi = Join-Path (Join-Path $ModsDir $ef) 'mod.info'
      if (@($droppedIds) -contains (Get-ModInfoId $eMi)) {
        $ed = Join-Path $ModsDir $ef
        if (Test-Path $ed) { Remove-Item $ed -Recurse -Force -ErrorAction SilentlyContinue; $removed++ }
      }
    }
    $prop.Value.folders = @($keptDirs | ForEach-Object { [string]$_.Name })
    if ($carryVariants) {
      if ($prop.Value.PSObject.Properties['variants']) { $prop.Value.variants = @($carryVariants) }
      else { $prop.Value | Add-Member -NotePropertyName 'variants' -NotePropertyValue @($carryVariants) }
    }
    return @{ Changed = $true; RemovedFolders = $removed }
  }
  if ($carryVariants -and -not ($storedV -and ((@($storedV) -join ',') -eq (@($carryVariants) -join ',')))) {
    # Choice recorded (e.g. picker kept all), but nothing dropped -
    # still persist the choice so updates do not re-ask.
    if ($prop.Value.PSObject.Properties['variants']) { $prop.Value.variants = @($carryVariants) }
    else { $prop.Value | Add-Member -NotePropertyName 'variants' -NotePropertyValue @($carryVariants) }
    return @{ Changed = $true; RemovedFolders = 0 }
  }
  return @{ Changed = $false; RemovedFolders = 0 }
}

function Open-GuiWorkshopPage {
  # Open a Steam Workshop page in the default browser
  # (Start-Process on the URL). Uses the HIGHLIGHTED row (the
  # ListView SelectedItem on the active tab), not the checked
  # boxes: click a row, then View. A highlighted row with a
  # numeric Workshop ID opens that mod's page; no highlighted
  # row (or a non-numeric ID) opens the Project Zomboid
  # Workshop main page - so the button is always useful and
  # never needs to be disabled.
  $wid = ''; $nm = ''
  $idx = -1
  if ($script:GuiTabControl) { $idx = $script:GuiTabControl.SelectedIndex }
  if ($idx -eq 0 -and $script:GuiModList) { $sel = $script:GuiModList.SelectedItem; if ($sel) { $wid = [string]$sel.WorkshopId; $nm = [string]$sel.Name } }
  elseif ($idx -eq 1 -and $script:GuiPackMemberList) { $sel = $script:GuiPackMemberList.SelectedItem; if ($sel) { $wid = [string]$sel.WorkshopId; $nm = [string]$sel.Name } }
  # A row whose Name is just its Workshop ID is an unresolved entry
  # (a random ID, or added while offline) - there is no real mod
  # page for it. No fallback to the main page here: Browse Workshop
  # is the button for that, so View never duplicates it. The button
  # is disabled when there is no valid highlight (see the tab
  # SelectionChanged handlers), so this no-op is only a safety net.
  if ($wid -match '^\d+$' -and $nm -ne '' -and $nm -ne $wid) { Start-Process ('https://steamcommunity.com/sharedfiles/filedetails/?id=' + $wid) }
}

function Manage-GuiModVariants {
  $script:AbortVariantBatch = $false
  # Manage variants: lists EVERY installed mod with multiple variant
  # folders (no pre-selection needed). Pick the mod(s) to revise, then
  # the variant picker opens with the current choice pre-ticked.
  # Dropped variant folders are deleted; the map entry is updated.
  # This is how already-installed mods get a variant pick revised -
  # Install's picker only fires on (re)install / update.
  $map = Get-InstallMap
  if (-not $map) { Set-GuiTransientStatus ('No installed mods found.'); return }
  $candidates = @()
  foreach ($prop in @($map.PSObject.Properties)) {
    $cid = [string]$prop.Name
    if ($cid -notmatch '^\d+$') { continue }
    if ($prop.Value.installed -ne $true -or -not $prop.Value.folders) { continue }
    $cfolders = @($prop.Value.folders | ForEach-Object { [string]$_ })
    if ($cfolders.Count -le 1) { continue }
    $cdirs = @()
    foreach ($cf in $cfolders) {
      $cfull = Join-Path $ModsDir $cf
      if (Test-Path $cfull) { $cdirs += (Get-Item $cfull) }
    }
    if ($cdirs.Count -le 1) { continue }
    $cName = $cid
    $cfm = @($Mods | Where-Object { [string]$_.WorkshopId -eq $cid })[0]
    if ($cfm) { $cName = [string]$cfm.Name }
    $candidates += [PSCustomObject]@{ Name = $cName; WorkshopId = $cid; VariantCount = $cdirs.Count }
  }
  if ($candidates.Count -eq 0) { Set-GuiTransientStatus ('No installed mods have multiple variants to manage.'); return }
  $pick = Show-GuiWpfPicker 'Manage Variants' 'Select the mod(s) whose variants you want to revise.' $candidates @(
    @{ Header = 'Name'; Property = 'Name'; Width = 500 },
    @{ Header = 'Variants'; Property = 'VariantCount'; Width = 100 },
    @{ Header = 'Workshop ID'; Property = 'WorkshopId'; Width = 150 }
  ) 'Manage Selected'
  if ($pick.Failed -or $pick.CancelAll) { return }
  $ids = @($pick.Selected | ForEach-Object { [string]$_.WorkshopId })
  if ($ids.Count -eq 0) { return }
  $considered = 0; $changedMods = 0; $removedFolders = 0; $mapDirty = $false
  $pendingManage = @()
  foreach ($id in $ids) {
    $prop = $map.PSObject.Properties[[string]$id]
    if (-not $prop) { continue }
    $folders = @($prop.Value.folders | ForEach-Object { [string]$_ })
    $dirs = @()
    foreach ($f in $folders) {
      $full = Join-Path $ModsDir $f
      if (Test-Path $full) { $dirs += (Get-Item $full) }
    }
    if ($dirs.Count -le 1) { continue }
    $considered++
    $modName = [string]$id
    $fm2 = @($Mods | Where-Object { [string]$_.WorkshopId -eq [string]$id })[0]
    if ($fm2) { $modName = [string]$fm2.Name }
    $storedV = $null
    if ($prop.Value.PSObject.Properties['variants']) { $storedV = @($prop.Value.variants | ForEach-Object { [string]$_ }) }
    $selRes = Select-KeptVariants $dirs $storedV $modName -DeferPicker -ForcePicker
    if ($selRes.Deferred) {
      $pendingManage += [PSCustomObject]@{ WorkshopId = [string]$id; Name = [string]$modName; VariantDirs = @($selRes.Folders); Candidates = @($selRes.Candidates); StoredVariants = $storedV; Prop = $prop; Folders = $folders; VersionDroppedIds = @($selRes.DroppedIds); Kind = 'Manage' }
    } else {
      $ap = Apply-ManageVariantDecision $prop $folders @($selRes.Folders) $selRes.CarryVariants @($selRes.DroppedIds) $storedV
      if ($ap.Changed) { $changedMods++; $removedFolders += $ap.RemovedFolders; $mapDirty = $true }
    }
  }
  # Consolidated picker: decide ALL deferred mods at once.
  if ($pendingManage.Count -gt 0) {
    $conRes = Show-GuiConsolidatedVariantPicker $pendingManage
    if ($conRes.CancelAll) {
      $script:AbortVariantBatch = $true
    } elseif ($conRes.Decisions) {
      foreach ($pd in $pendingManage) {
        if ($script:AbortVariantBatch) { break }
        $dec = $conRes.Decisions[[string]$pd.WorkshopId]
        if (-not $dec) { continue }
        if (@($dec.KeptIndices).Count -eq 0) { continue }
        $keepSet = @{}
        foreach ($ki in @($dec.KeptIndices)) { $keepSet[[int]$ki] = $true }
        $keptDirs = @(); $pickerDropped = @()
        for ($vi = 0; $vi -lt @($pd.VariantDirs).Count; $vi++) {
          if ($keepSet.ContainsKey($vi)) { $keptDirs += $pd.VariantDirs[$vi] }
          else {
            $mid = Get-ModInfoId (Join-Path $pd.VariantDirs[$vi].FullName 'mod.info')
            if ($mid -ne '') { $pickerDropped += $mid }
          }
        }
        $droppedIds = @(@($pd.VersionDroppedIds) + @($pickerDropped))
        $ap = Apply-ManageVariantDecision $pd.Prop $pd.Folders $keptDirs @($dec.KeptIds) $droppedIds $pd.StoredVariants
        if ($ap.Changed) { $changedMods++; $removedFolders += $ap.RemovedFolders; $mapDirty = $true }
      }
    }
  }
  if ($mapDirty) { Save-InstallMap $map; Clear-DiskModIdMap }
  if ($script:AbortVariantBatch) { Set-GuiTransientStatus ('Variants cancelled.'); return }
  if ($considered -eq 0) { Set-GuiTransientStatus ('No multi-variant mods to manage.'); return }
  if ($changedMods -eq 0) { Set-GuiTransientStatus ('Variants: no changes - kept all selected variants.'); return }
  Set-GuiTransientStatus ('Variants: removed ' + $removedFolders + ' variant folder(s) across ' + $changedMods + ' mod(s).')
  # Standard: refresh every view after folders change.
  Refresh-GuiAfterListChange
}

function New-GuiNamedList {
  $nm = Read-GuiInput 'Name for the new list' 'PZ Mod Manager' ''
  if (-not $nm) { return }
  $safe = Get-SafeListName $nm
  if (Test-Path (Join-Path $ListsDir ($safe + '.json'))) {
    Set-GuiTransientStatus ("A list named '" + $nm + "' already exists.")
    return
  }
  Save-NamedListData $safe $nm @()
  Set-GuiTransientStatus ("Created list '" + $nm + "' (0 mods).")
  # The new list becomes active: the whole UI (Mods/Packs/Lists/
  # Categories/detail) switches to it. Otherwise the new list just
  # appears in the table while active + detail still point at the old
  # list, which reads as "the list didn't refresh". Activate-GuiList
  # does the full refresh, so no separate Refresh call is needed.
  Activate-GuiList $safe
}

function Rename-GuiSelectedList {
  # Rename needs exactly one list (the dialog names one list).
  if (-not $script:GuiSelectedLists -or $script:GuiSelectedLists.Count -ne 1) { Set-GuiTransientStatus ('Select exactly one list to rename.'); return }
  Rename-GuiNamedList @($script:GuiSelectedLists.Keys)[0]
}

function Rename-GuiNamedList([string]$safe) {
  $d = Get-NamedListData $safe
  if (-not $d) { Set-GuiTransientStatus ('List not found.'); return }
  $newName = Read-GuiInput 'New name' 'PZ Mod Manager' $d.name
  if (-not $newName -or $newName -eq $d.name) { return }
  $newSafe = Get-SafeListName $newName
  if (($newSafe -ne $safe) -and (Test-Path (Join-Path $ListsDir ($newSafe + '.json')))) {
    Set-GuiTransientStatus ("A list named '" + $newName + "' already exists.")
    return
  }
  Save-NamedListData $newSafe $newName @($d.mods)
  # Only move the file / active pointer when the Safe really changed: on a
  # case-insensitive filesystem a case-only rename targets the same file, and
  # deleting it would lose the list.
  $safeChanged = ($newSafe -ne $safe) -and ($newSafe.ToLower() -ne $safe.ToLower())
  if ($safeChanged) {
    Remove-Item (Join-Path $ListsDir ($safe + '.json')) -Force -ErrorAction SilentlyContinue
    if ((Get-ActiveListSafe) -eq $safe) { Set-ActiveListSafe $newSafe }
  }
  # Keep the selection on the renamed list: the selection is keyed by
  # Safe, so move the old key to the new Safe. Otherwise the item
  # shows unselected while the count still says 1 selected.
  if ($script:GuiSelectedLists -and $script:GuiSelectedLists.ContainsKey($safe) -and ($newSafe.ToLower() -ne $safe.ToLower())) {
    $script:GuiSelectedLists.Remove($safe)
    $script:GuiSelectedLists[$newSafe] = $true
  }
  Set-GuiTransientStatus ("Renamed to '" + $newName + "'.")
  Refresh-GuiAfterListChange
}

function Update-GuiListSelectionButtons {
  # Refresh the Lists header bulk buttons: Install/Delete selected show
  # the selection count and disable at 0; Select-all toggles to Clear
  # selection when every shown named list is selected.
  $n = 0
  if ($script:GuiSelectedLists) { $n = $script:GuiSelectedLists.Count }
  if ($script:GuiListRenameDeleteButton) {
    # Merged Rename / Delete: enabled when anything is selected; the
    # menu itself enables Rename only for exactly one selection.
    $script:GuiListRenameDeleteButton.IsEnabled = ($n -gt 0)
  }
  if ($script:GuiSetActiveListButton) {
    # Set active needs exactly one selected list, and it must not already
    # be the active list (there is nothing to change).
    $setActive = $false
    if ($n -eq 1) {
      $selSafe = @($script:GuiSelectedLists.Keys)[0]
      if ([string]$selSafe -ne (Get-ActiveListSafe)) { $setActive = $true }
    }
    $script:GuiSetActiveListButton.IsEnabled = $setActive
  }
  if ($script:GuiExportSelectedListButton) {
    # Export needs at least one selected list (no active-list fallback:
    # the button says 'Export selected list').
    $script:GuiExportSelectedListButton.IsEnabled = ($n -gt 0)
  }
  Sync-GuiHeaderCheckbox $script:GuiNamedListView 'SelectAllLists' $script:GuiListsShownIds $script:GuiSelectedLists
}


function Set-GuiActiveList {
  # Set the selected list (exactly one) as the active list, so Mods /
  # Packs / Categories all switch to it. (Clicking a row also activates,
  # but ticking + Set active is explicit.)
  if (-not $script:GuiSelectedLists -or $script:GuiSelectedLists.Count -ne 1) { Set-GuiTransientStatus ('Select exactly one list to set it active.'); return }
  $safe = @($script:GuiSelectedLists.Keys)[0]
  Activate-GuiList $safe
}

function Delete-GuiSelectedLists {
  # Delete every checked named list. One confirm for the batch. If the
  # active list is among them, fall back to Default. Clears the selection.
  if (-not $script:GuiSelectedLists -or $script:GuiSelectedLists.Count -eq 0) { Set-GuiTransientStatus ('Select at least one list first.'); return }
  $safes = @($script:GuiSelectedLists.Keys)
  $names = @()
  foreach ($safe in $safes) {
    $d = Get-NamedListData $safe
    if ($d) { $names += [string]$d.name }
  }
  if ($names.Count -eq 0) { Set-GuiTransientStatus ('Selected lists not found.'); return }
  $res = Show-GuiMessageBox ('Delete ' + $names.Count + ' selected lists (' + ($names -join ', ') + ')?') 'PZ Mod Manager' ([System.Windows.MessageBoxButton]::YesNo) ([System.Windows.MessageBoxImage]::Warning)
  if ($res -ne [System.Windows.MessageBoxResult]::Yes) { return }
  $wasActive = $false
  foreach ($safe in $safes) {
    if ((Get-ActiveListSafe) -eq $safe) { $wasActive = $true }
    Remove-Item (Join-Path $ListsDir ($safe + '.json')) -Force -ErrorAction SilentlyContinue
  }
  if ($wasActive) {
    $remaining = @(Get-NamedLists)
    if ($remaining.Count -gt 0) { Set-ActiveListSafe $remaining[0].Safe; [void](Set-ModsFromNamedList $remaining[0].Safe) }
    else { Set-ActiveListSafe ''; $script:Mods = @() }
  }
  $script:GuiSelectedLists = @{}
  $script:GuiListSelectionDirty = $true
  Set-GuiTransientStatus (('Deleted ' + $names.Count + ' selected lists.'))
  Refresh-GuiAfterListChange
}


function Show-GuiRejectedWorkshopIds($rejected) {
  # Report IDs the Add handlers refused (not found / wrong game).
  # A MessageBox, not the status bar, so it does not overwrite the
  # 'Added N mod(s)' confirmation for the IDs that did go in.
  if (-not $rejected -or @($rejected).Count -eq 0) { return }
  $lines = @($rejected | ForEach-Object { [string]$_.WorkshopId + ' - ' + [string]$_.RejectReason })
  [void](Show-GuiMessageBox ('Not added (not a Project Zomboid Workshop mod):`n' + ($lines -join "`n")) 'Add mods' ([System.Windows.MessageBoxButton]::OK) ([System.Windows.MessageBoxImage]::Warning))
}

function Add-ModToActiveListIfMissing([string]$workshopId) {
  # Add an auto-installed dependency to the active list if it is not
  # already there (dedup by Workshop ID). Marks it autoDep=$true, so
  # uninstall can tell auto-added deps from mods the user picked.
  # Name resolves from the installed mod.info; Cat is Others (a dep
  # is not a catalog mod). No UI refresh - the batch's final refresh
  # picks it up.
  $safe = Get-ActiveListSafe
  if ($safe -eq '') { return }
  $d = Get-NamedListData $safe
  if (-not $d) { return }
  $listMods = @($d.mods)
  foreach ($mm in $listMods) { if ([string]$mm.workshopId -eq [string]$workshopId) { return } }
  $depName = [string]$workshopId
  $depMap = Get-InstallMap
  if ($depMap -and $depMap.PSObject.Properties[$workshopId] -and $depMap.PSObject.Properties[$workshopId].Value.folders) {
    $depFolder = [string]$depMap.PSObject.Properties[$workshopId].Value.folders[0]
    $depMi = Join-Path (Join-Path $ModsDir $depFolder) 'mod.info'
    try {
      $depRaw = Get-Content $depMi -Raw -ErrorAction Stop
      $depNm = [regex]::Match($depRaw, '(?m)^\s*name\s*=\s*(.+?)\s*$')
      if ($depNm.Success -and $depNm.Groups[1].Value.Trim() -ne '') { $depName = $depNm.Groups[1].Value.Trim() }
    } catch { }
  }
  $listMods += [PSCustomObject]@{ workshopId = [string]$workshopId; name = $depName; cat = 'Others'; autoDep = $true }
  Save-NamedListData $safe $d.name $listMods
}


function Add-GuiListMembers([string]$safe, $entries) {
  # Adds one or more mods to a list in a single save (dedup by Workshop ID).
  $entries = Resolve-EntryCategories $entries
  $d = Get-NamedListData $safe
  if (-not $d) { return }
  $listMods = @($d.mods)
  $have = @{}
  foreach ($mm in $listMods) { $have[[string]$mm.workshopId] = $true }
  $added = 0
  foreach ($e in $entries) {
    if (-not $have.ContainsKey([string]$e.WorkshopId)) {
      $listMods += [PSCustomObject]@{ workshopId = [string]$e.WorkshopId; name = [string]$e.Name; cat = [string]$e.Cat }
      $have[[string]$e.WorkshopId] = $true
      $added++
    }
  }
  if ($added -eq 0) { Set-GuiTransientStatus ('Already in list.'); return }
  Save-NamedListData $safe $d.name $listMods
  if ($safe -eq (Get-ActiveListSafe)) { [void](Set-ModsFromNamedList $safe) }
  Set-GuiTransientStatus ("Added $added mod(s) to list.")
  Refresh-GuiAfterListChange
}


function Cycle-GuiListsSort([string]$col) {
  # Click a Lists header: toggle ascending <-> descending. Never clears.
  if ($script:GuiListsSortColumn -eq $col) {
    $script:GuiListsSortDescending = -not $script:GuiListsSortDescending
  } else { $script:GuiListsSortColumn = $col; $script:GuiListsSortDescending = $false }
  Refresh-GuiNamedLists
}
function Activate-GuiList([string]$safe) {
  # Click a list in the Lists tab: it becomes active, so the Mods /
  # Packs / Categories tabs all switch to that list's content.
  # Guard: Refresh-GuiNamedLists re-sets ItemsSource, which re-fires
  # SelectionChanged; the guard stops the re-entrant call.
  if ($script:GuiActivatingList) { return }
  $script:GuiActivatingList = $true
  try {
    if ($safe -eq '') { return }
    # No early return when $safe is already active: always do the full
    # refresh. If the tabs ever desync from active.txt (a refresh was
    # interrupted, or a stale SelectionChanged fired), clicking the
    # active list re-syncs them instead of leaving stale content.
    # Refresh-GuiNamedLists already refreshes the detail pane, so the
    # old detail-only path is covered by the full refresh below.
    Set-ActiveListSafe $safe
    if (-not (Set-ModsFromNamedList $safe)) { Set-ActiveListSafe ''; $script:Mods = @(); return }
    $script:GuiSelectedMods = @{}
    $script:GuiSelectionDirty = $true
    # Standard: refresh every view after this change (one composite call).
    Refresh-GuiAfterListChange
  } finally {
    $script:GuiActivatingList = $false
  }
}

function Write-GuiListFile([string]$path, $d, [string]$ext) {
  # Write ONE list to $path. Format follows $ext: .json (full: mods +
  # packs + categories), .csv (mod table), .txt (one Workshop ID per line).
  if ($ext -eq '.csv') {
    $packOf = @{}
    foreach ($p in @($d.packs)) {
      foreach ($id in @($p.ids)) { if (-not $packOf.ContainsKey([string]$id)) { $packOf[[string]$id] = [string]$p.name } }
    }
    $lines = @('workshopId,name,cat,pack')
    foreach ($m in @($d.mods)) {
      $wid = [string]$m.workshopId
      $pk = ''
      if ($packOf.ContainsKey($wid)) { $pk = $packOf[$wid] }
      $lines += ('"' + $wid + '","' + ([string]$m.name -replace '"', '""') + '","' + ([string]$m.cat -replace '"', '""') + '","' + ($pk -replace '"', '""') + '"')
    }
    $lines | Set-Content $path -Encoding UTF8
  } elseif ($ext -eq '.txt') {
    @(@($d.mods) | ForEach-Object { [string]$_.workshopId }) | Set-Content $path -Encoding UTF8
  } else {
    $obj = [PSCustomObject]@{ name = [string]$d.name; created = [string]$d.created; mods = @($d.mods); packs = @($d.packs); categories = @($d.categories) }
    $obj | ConvertTo-Json -Depth 5 | Set-Content $path -Encoding UTF8
  }
}

function Write-GuiMergedListFile([string]$path, $lists, [string]$ext) {
  # Write MULTIPLE lists to ONE file. JSON keeps the list boundaries
  # ({lists: [...]}) so a merged export round-trips back to separate
  # lists on import. CSV/TXT are flat, so they concatenate + dedupe by
  # Workshop ID (first occurrence wins).
  if ($ext -eq '.csv') {
    $packOf = @{}
    $seen = @{}
    $lines = @('workshopId,name,cat,pack')
    foreach ($d in $lists) {
      foreach ($p in @($d.packs)) {
        foreach ($id in @($p.ids)) { if (-not $packOf.ContainsKey([string]$id)) { $packOf[[string]$id] = [string]$p.name } }
      }
    }
    foreach ($d in $lists) {
      foreach ($m in @($d.mods)) {
        $wid = [string]$m.workshopId
        if ($seen.ContainsKey($wid)) { continue }
        $seen[$wid] = $true
        $pk = ''
        if ($packOf.ContainsKey($wid)) { $pk = $packOf[$wid] }
        $lines += ('"' + $wid + '","' + ([string]$m.name -replace '"', '""') + '","' + ([string]$m.cat -replace '"', '""') + '","' + ($pk -replace '"', '""') + '"')
      }
    }
    $lines | Set-Content $path -Encoding UTF8
  } elseif ($ext -eq '.txt') {
    $seen = @{}
    $ids = @()
    foreach ($d in $lists) {
      foreach ($m in @($d.mods)) {
        $wid = [string]$m.workshopId
        if ($seen.ContainsKey($wid)) { continue }
        $seen[$wid] = $true
        $ids += $wid
      }
    }
    $ids | Set-Content $path -Encoding UTF8
  } else {
    $arr = @()
    foreach ($d in $lists) {
      $arr += [PSCustomObject]@{ name = [string]$d.name; created = [string]$d.created; mods = @($d.mods); packs = @($d.packs); categories = @($d.categories) }
    }
    ([PSCustomObject]@{ lists = $arr }) | ConvertTo-Json -Depth 6 | Set-Content $path -Encoding UTF8
  }
}

function Export-GuiList {
  # Export selected lists to .json (full: mods + packs + categories), .csv
  # (mod table), or .txt (one Workshop ID per line). Format follows the
  # chosen file extension. The button is disabled with nothing selected;
  # Export needs at least one selected list (no active-list fallback).
  # The merge/separate choice appears on click, before the file dialog:
  # Separate = one file per list; Merged = one file (JSON keeps list
  # boundaries via {lists: [...]}, CSV/TXT concatenate + dedupe).
  $safes = @()
  if ($script:GuiSelectedLists -and $script:GuiSelectedLists.Count -gt 0) { $safes = @($script:GuiSelectedLists.Keys) }
  if ($safes.Count -eq 0) { Set-GuiTransientStatus 'Select at least one list to export.'; return }
  $lists = @()
  foreach ($sf in $safes) {
    $dd = Get-NamedListData $sf
    if ($dd) { $lists += $dd }
  }
  if ($lists.Count -eq 0) { Set-GuiTransientStatus 'List not found.'; return }
  $mode = Show-GuiChoiceDialog 'Export Lists' ('Export ' + $lists.Count + ' list(s) as:') 'Separate Files (One Per List)' 'Merged Into One File'
  if ($mode -eq 0) { return }
  try {
    if ($mode -eq 2) {
      $dlg = New-Object Microsoft.Win32.SaveFileDialog
      $dlg.Title = 'Export merged lists'
      $dlg.FileName = 'merged-lists'
      $dlg.Filter = 'JSON list (*.json)|*.json|CSV table (*.csv)|*.csv|Text (Workshop IDs) (*.txt)|*.txt'
      $dlg.DefaultExt = 'json'
      if (-not $dlg.ShowDialog()) { return }
      $path = $dlg.FileName
      $ext = [IO.Path]::GetExtension($path).ToLower()
      Write-GuiMergedListFile $path $lists $ext
      Set-GuiTransientStatus ('Exported ' + $lists.Count + ' list(s) (merged) to ' + [IO.Path]::GetFileName($path) + '.')
    } else {
      $dlg = New-Object Microsoft.Win32.SaveFileDialog
      $dlg.Title = 'Export list'
      $dlg.FileName = (Get-SafeListName ([string]$lists[0].name))
      $dlg.Filter = 'JSON list (*.json)|*.json|CSV table (*.csv)|*.csv|Text (Workshop IDs) (*.txt)|*.txt'
      $dlg.DefaultExt = 'json'
      if (-not $dlg.ShowDialog()) { return }
      $path = $dlg.FileName
      $ext = [IO.Path]::GetExtension($path).ToLower()
      $folder = [IO.Path]::GetDirectoryName($path)
      Write-GuiListFile $path $lists[0] $ext
      for ($i = 1; $i -lt $lists.Count; $i++) {
        $fn = (Get-SafeListName ([string]$lists[$i].name)) + $ext
        Write-GuiListFile (Join-Path $folder $fn) $lists[$i] $ext
      }
      Set-GuiTransientStatus ('Exported ' + $lists.Count + ' list(s) to separate files in ' + $folder + '.')
    }
  } catch {
    Set-GuiTransientStatus ('Export failed: ' + $_.Exception.Message)
  }
}

function Get-ListsFromFile([string]$path) {
  # Parse one import file into an array of list objects (@{Name; Mods;
  # Packs; Categories}). A merged JSON export ({lists: [...]}) yields one
  # element per list; CSV/TXT/single JSON yield one element.
  $ext = [IO.Path]::GetExtension($path).ToLower()
  if ($ext -eq '.csv') {
    $packGroups = @{}
    $mods = @()
    foreach ($r in (Import-Csv $path)) {
      $wid = [string]$r.workshopId
      if ($wid -eq '') { continue }
      $mn = [string]$r.name; if ($mn -eq '') { $mn = $wid }
      $ct = [string]$r.cat; if ($ct -eq '' -or $ct -eq 'Custom') { $ct = 'Others' }
      $mods += [PSCustomObject]@{ workshopId = $wid; name = $mn; cat = $ct }
      $pk = [string]$r.pack
      if ($pk -ne '') {
        if (-not $packGroups.ContainsKey($pk)) { $packGroups[$pk] = @() }
        $packGroups[$pk] += $wid
      }
    }
    $packs = @()
    foreach ($pk in @($packGroups.Keys)) {
      $packs += [PSCustomObject]@{ name = $pk; desc = ''; ids = @($packGroups[$pk]); source = '' }
    }
    return @(@{ Name = [IO.Path]::GetFileNameWithoutExtension($path); Mods = $mods; Packs = $packs; Categories = @() })
  } elseif ($ext -eq '.txt') {
    $catalog = @{}
    foreach ($c in (Get-FullModCatalog)) { $catalog[[string]$c.WorkshopId] = $c }
    $seen = @{}
    $mods = @()
    foreach ($line in @(Get-Content $path)) {
      foreach ($id in @(Parse-ModIdsFromText ([string]$line))) {
        if ($seen.ContainsKey($id)) { continue }
        $seen[$id] = $true
        $mn = $id; $ct = 'Others'
        if ($catalog.ContainsKey($id)) { $mn = [string]$catalog[$id].Name; $ct = [string]$catalog[$id].Cat }
        else {
          $steamName = Get-WorkshopModName $id
          if ($steamName) { $mn = $steamName }
        }
        $mods += [PSCustomObject]@{ workshopId = $id; name = $mn; cat = $ct }
      }
    }
    return @(@{ Name = [IO.Path]::GetFileNameWithoutExtension($path); Mods = $mods; Packs = @(); Categories = @() })
  } else {
    $obj = Get-Content $path -Raw -ErrorAction Stop | ConvertFrom-Json
    if ($obj.lists -and @($obj.lists).Count -gt 0) {
      $out = @()
      foreach ($entry in @($obj.lists)) {
        $out += @{ Name = [string]$entry.name; Mods = @(@($entry.mods) | ForEach-Object { [PSCustomObject]@{ workshopId = [string]$_.workshopId; name = [string]$_.name; cat = [string]$_.cat } } | Where-Object { [string]$_.workshopId -ne '' }); Packs = @(@($entry.packs) | ForEach-Object { [PSCustomObject]@{ name = [string]$_.name; desc = [string]$_.desc; ids = @($_.ids); source = [string]$_.source } }); Categories = @(@($entry.categories) | ForEach-Object { [string]$_ }) }
      }
      return $out
    }
    $name = [IO.Path]::GetFileNameWithoutExtension($path)
    if ([string]$obj.name -ne '') { $name = [string]$obj.name }
    $mods = @(@($obj.mods) | ForEach-Object { [PSCustomObject]@{ workshopId = [string]$_.workshopId; name = [string]$_.name; cat = [string]$_.cat } } | Where-Object { [string]$_.workshopId -ne '' })
    $packs = @(@($obj.packs) | ForEach-Object { [PSCustomObject]@{ name = [string]$_.name; desc = [string]$_.desc; ids = @($_.ids); source = [string]$_.source } })
    $categories = @(@($obj.categories) | ForEach-Object { [string]$_ })
    return @(@{ Name = $name; Mods = $mods; Packs = $packs; Categories = $categories })
  }
}

function Save-GuiImportedList([string]$name, $mods, $packs, $categories) {
  # Save an imported list (never overwrites an existing one - a
  # colliding name gets ' 2', ' 3', ...). Returns the safe name.
  $safe = Get-SafeListName $name
  $base = $safe; $n = 2
  while (Test-Path (Join-Path $ListsDir ($safe + '.json'))) { $safe = $base + ' ' + $n; $n++ }
  Save-NamedListData $safe $name $mods $packs $categories
  return $safe
}

function Import-GuiList {
  # Import list(s) from .json (full), .csv (mod table), or .txt (one
  # Workshop ID / URL per line). Creates new lists (never overwrites
  # an existing one). The merge/separate choice appears on click,
  # before the file dialog: Separate = one list per file (a merged
  # JSON yields one list per entry); Merged = all files combined
  # into one list (mods deduped, packs merged by name, name prompted).
  $mode = Show-GuiChoiceDialog 'Import Lists' 'Import as:' 'Separate Lists (One Per File)' 'Merged Into One List'
  if ($mode -eq 0) { return }
  $dlg = New-Object Microsoft.Win32.OpenFileDialog
  $dlg.Title = 'Import list'
  $dlg.Filter = 'JSON list (*.json)|*.json|CSV table (*.csv)|*.csv|Text (Workshop IDs) (*.txt)|*.txt|All files (*.*)|*.*'
  $dlg.Multiselect = $true
  if (-not $dlg.ShowDialog()) { return }
  $paths = @($dlg.FileNames)
  if ($paths.Count -eq 0) { return }
  try {
    $all = @()
    foreach ($p in $paths) {
      foreach ($entry in @(Get-ListsFromFile $p)) { $all += $entry }
    }
    $all = @($all | Where-Object { @($_.Mods).Count -gt 0 })
    if ($all.Count -eq 0) { Set-GuiTransientStatus 'Nothing to import (no mods found).'; return }
    if ($mode -eq 2) {
      $mergedName = Read-GuiInput 'Name for the merged list' 'PZ Mod Manager' 'Merged'
      if (-not $mergedName) { return }
      $seen = @{}
      $mods = @()
      $packGroups = @{}
      $packMeta = @{}
      $cats = @{}
      foreach ($entry in $all) {
        foreach ($m in @($entry.Mods)) {
          $wid = [string]$m.workshopId
          if ($seen.ContainsKey($wid)) { continue }
          $seen[$wid] = $true
          $mods += $m
        }
        foreach ($pk in @($entry.Packs)) {
          $pn = [string]$pk.name
          if (-not $packGroups.ContainsKey($pn)) { $packGroups[$pn] = @(); $packMeta[$pn] = $pk }
          foreach ($id in @($pk.ids)) { if ($packGroups[$pn] -notcontains [string]$id) { $packGroups[$pn] += [string]$id } }
        }
        foreach ($c in @($entry.Categories)) { $cats[[string]$c] = $true }
      }
      $packs = @()
      foreach ($pn in @($packGroups.Keys)) {
        $packs += [PSCustomObject]@{ name = $pn; desc = [string]$packMeta[$pn].desc; ids = @($packGroups[$pn]); source = [string]$packMeta[$pn].source }
      }
      $categories = @($cats.Keys)
      [void](Save-GuiImportedList $mergedName $mods $packs $categories)
      Set-GuiTransientStatus ('Imported merged list "' + $mergedName + '" (' + $mods.Count + ' mods). Select it and click Set active to make it active.')
    } else {
      $names = @()
      foreach ($entry in $all) {
        [void](Save-GuiImportedList ([string]$entry.Name) @($entry.Mods) @($entry.Packs) @($entry.Categories))
        $names += [string]$entry.Name
      }
      Set-GuiTransientStatus ('Imported ' + $all.Count + ' list(s): ' + ($names -join ', ') + '. Select one and click Set active to make it active.')
    }
    # Standard: refresh every view after this change (one composite call).
    Refresh-GuiAfterListChange
  } catch {
    Set-GuiTransientStatus ('Import failed: ' + $_.Exception.Message)
  }
}

function Refresh-GuiNamedLists {
  # Lists tab is a ListView + GridView (same table layout as the Mods tab):
  # one row per list, sortable headers, resizable columns. The selected
  # list's members show in the detail table below (Add / Remove there).
  # A list is a full profile: mods + packs + categories. Click a list to
  # view its members in the detail pane. Set active (tick + button) makes
  # a list active (Mods/Packs/Categories switch to it). No Active column:
  # the active list's name carries an ' (active)' suffix. Default is a
  # normal list (lists/default.json) - deletable, checkable, renameable.
  if (-not $script:GuiNamedListView) { return }
  if (-not $script:GuiSelectedLists) { $script:GuiSelectedLists = @{} }
  if (-not $script:GuiSelectedMods) { $script:GuiSelectedMods = @{} }
  $active = Get-ActiveListSafe
  $search = ''
  if ($script:GuiListSearch) { $search = [string]$script:GuiListSearch }
  $search = $search.Trim()
  $rows = @()
  $namedLists = @(Get-NamedLists)
  # Drop stale selection keys (a list renamed/deleted without moving
  # its key): the count must match what's actually selected. Prune
  # against ALL lists, not just the search-filtered shown ones, so a
  # search never wipes a selection.
  $allSafes = @($namedLists | ForEach-Object { [string]$_.Safe })
  foreach ($k in @($script:GuiSelectedLists.Keys)) { if ($allSafes -notcontains $k) { $script:GuiSelectedLists.Remove($k) } }
  $script:GuiListsShownIds = @{}
  foreach ($l in $namedLists) {
    if ($search -ne '' -and $l.Name -notmatch [regex]::Escape($search)) { continue }
    $script:GuiListsShownIds[$l.Safe] = $true
    $d = Get-NamedListData $l.Safe
    $listMods = @()
    if ($d) { $listMods = @($d.mods) }
    # Backfill names for members added by ID before name lookup existed.
    $listChanged = $false
    foreach ($mm in $listMods) {
      if (([string]$mm.name -eq [string]$mm.workshopId -or [string]$mm.name -eq '') -and [string]$mm.workshopId -ne '') {
        $steamName = Get-WorkshopModName ([string]$mm.workshopId)
        if ($steamName) { $mm.name = $steamName; $listChanged = $true }
      }
    }
    if ($listChanged) { Save-NamedListData $l.Safe $d.name $listMods }
    $dispName = [string]$l.Name
    if ($l.Safe -eq $active) { $dispName += ' (active)' }
    $rows += [PSCustomObject]@{ Name = $dispName; Date = [string]$d.created; Mods = $listMods.Count; Safe = [string]$l.Safe; IsChecked = $script:GuiSelectedLists.ContainsKey($l.Safe) }
  }
  $col = $script:GuiListsSortColumn
  if ($col -eq 'Name') { if ($script:GuiListsSortDescending) { $rows = @($rows | Sort-Object Name -Descending) } else { $rows = @($rows | Sort-Object Name) } }
  elseif ($col -eq 'Mods') { if ($script:GuiListsSortDescending) { $rows = @($rows | Sort-Object Mods -Descending) } else { $rows = @($rows | Sort-Object Mods) } }
  elseif ($col -eq 'Date') { if ($script:GuiListsSortDescending) { $rows = @($rows | Sort-Object Date, Name -Descending) } else { $rows = @($rows | Sort-Object Date, Name) } }
  $script:GuiNamedListView.ItemsSource = $rows
  # Header select-all checkbox (lists table).
  if ($script:GuiNamedListView.View -and $script:GuiNamedListView.View.Columns -and $script:GuiNamedListView.View.Columns.Count -gt 0) {
    $hdrCb = $script:GuiNamedListView.View.Columns[0].Header
    if ($hdrCb -is [System.Windows.Controls.CheckBox]) {
      $selCount = 0
      foreach ($r in $rows) { if ($r.IsChecked) { $selCount++ } }
      if ($rows.Count -eq 0 -or $selCount -eq 0) { $hdrCb.IsChecked = $false }
      elseif ($selCount -eq $rows.Count) { $hdrCb.IsChecked = $true }
      else { $hdrCb.IsChecked = $false }
    }
  }
  # Header sort indicators.
  if ($script:GuiNamedListView.View -and $script:GuiNamedListView.View.Columns) {
    $gvCols = $script:GuiNamedListView.View.Columns
    $plain = @('Name', 'Created Date', 'Mods')
    for ($i = 0; $i -lt 3 -and ($i + 1) -lt $gvCols.Count; $i++) { $gvCols[$i + 1].Header = $plain[$i] }
    if ($col -eq 'Name') { $gvCols[1].Header = if ($script:GuiListsSortDescending) { 'Name (Z-A)' } else { 'Name (A-Z)' } }
    elseif ($col -eq 'Date') { $gvCols[2].Header = if ($script:GuiListsSortDescending) { 'Created Date (newest)' } else { 'Created Date (oldest)' } }
    elseif ($col -eq 'Mods') { $gvCols[3].Header = if ($script:GuiListsSortDescending) { 'Mods (9-0)' } else { 'Mods (0-9)' } }
  }
  $script:GuiListsShown = $rows.Count
  $script:GuiListsTotal = @(Get-NamedLists).Count
  Update-GuiListSelectionButtons
  Update-GuiStatusBar
  Sync-GuiHeaderCheckbox $script:GuiNamedListView 'SelectAllLists' $script:GuiListsShownIds $script:GuiSelectedLists
}

function Set-GuiWindowIcon {
  # Game icon on the GUI window (title bar + taskbar). RESTORED to the
  # original pre-v279 implementation that worked.
  try {
    if (-not $script:GuiWindow) { return }
    $game = Find-GameFolder -AllowPrompt:$false
    if (-not $game) { return }
    $exe = Join-Path $game 'ProjectZomboid64.exe'
    if (-not (Test-Path $exe)) { return }
    Add-Type -AssemblyName System.Drawing
    $icon = [System.Drawing.Icon]::ExtractAssociatedIcon($exe)
    if (-not $icon) { return }
    $script:GuiIcon = $icon
    $script:GuiWindow.Add_Loaded({
      try {
        $helper = New-Object System.Windows.Interop.WindowInteropHelper($script:GuiWindow)
        $hwnd = $helper.Handle
        if ($hwnd -ne [System.IntPtr]::Zero) {
          $r1 = [Win32.ConsoleHider]::SendMessage($hwnd, 0x0080, [System.IntPtr]1, $script:GuiIcon.Handle)
          $r2 = [Win32.ConsoleHider]::SendMessage($hwnd, 0x0080, [System.IntPtr]0, $script:GuiIcon.Handle)
        }
      } catch { }
    })
  } catch { }
}


function Set-DialogWindowIcon($window) {
  # Dialog-window icon (picker / input prompt).
  try {
    # Load WinForms BEFORE the [System.Windows.Forms.Form] type check below.
    # Without this, the type literal throws 'Unable to find type
    # [System.Windows.Forms.Form]' when only WPF is loaded (the WPF picker
    # opens before any WinForms dialog), the outer catch swallows it, and
    # the function returns early - Window.Icon + WM_SETICON never run.
    # That was the real cause of the popup PowerShell icon (found by the
    # v288 diagnostic, not by guessing).
    Add-Type -AssemblyName System.Windows.Forms
    if (-not $window -or -not $script:GuiIcon) {
      return
    }
    if ($window -is [System.Windows.Forms.Form]) { $window.Icon = $script:GuiIcon; return }
    try {
      $ms = New-Object System.IO.MemoryStream
      $script:GuiIcon.ToBitmap().Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
      $ms.Position = 0
      $img = New-Object System.Windows.Media.Imaging.BitmapImage
      $img.BeginInit()
      $img.StreamSource = $ms
      $img.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
      $img.EndInit()
      $img.Freeze()
      $window.Icon = $img
    } catch { }
    $script:GuiDialogWindow = $window
    $window.Add_Loaded({
      try {
        $helper = New-Object System.Windows.Interop.WindowInteropHelper($script:GuiDialogWindow)
        $hwnd = $helper.Handle
        if ($hwnd -ne [System.IntPtr]::Zero) {
          $r1 = [Win32.ConsoleHider]::SendMessage($hwnd, 0x0080, [System.IntPtr]1, $script:GuiIcon.Handle)
          $r2 = [Win32.ConsoleHider]::SendMessage($hwnd, 0x0080, [System.IntPtr]0, $script:GuiIcon.Handle)
        }
      } catch { }
    })
  } catch { }
}



function Show-GuiMessageBox([string]$msg, [string]$title, $buttons, $image) {
  # THE MessageBox standard: main window as owner, so the box inherits
  # the game icon. A bare MessageBox shows the PowerShell icon.
  if ($script:GuiWindow) {
    return [System.Windows.MessageBox]::Show($script:GuiWindow, $msg, $title, $buttons, $image)
  }
  return [System.Windows.MessageBox]::Show($msg, $title, $buttons, $image)
}




function Register-LastColumnFill($listView) {
  # Last GridView column stretches to the ListView edge (no blank space on
  # the right). Its left edge stays draggable (via the previous column's
  # gripper); its right edge is pinned to the ListView edge. The width is
  # measured from the inner ScrollViewer's ViewportWidth, which already
  # excludes the vertical scrollbar ONLY when it is actually visible --
  # a fixed allowance leaves a sliver on tables with no scrollbar.
  if (-not $listView -or -not $listView.View -or -not $listView.View.Columns -or $listView.View.Columns.Count -eq 0) { return }
  $cols = $listView.View.Columns
  $cachedSv = $null
  $handler = {
    if (-not $cachedSv) {
      $queue = New-Object System.Collections.Generic.Queue[System.Windows.DependencyObject]
      $queue.Enqueue($listView)
      while ($queue.Count -gt 0 -and -not $cachedSv) {
        $obj = $queue.Dequeue()
        if ($obj -is [System.Windows.Controls.ScrollViewer]) { $cachedSv = $obj; break }
        if ($obj -is [System.Windows.Media.Visual]) {
          $n = [System.Windows.Media.VisualTreeHelper]::GetChildrenCount($obj)
          for ($i = 0; $i -lt $n; $i++) { $queue.Enqueue([System.Windows.Media.VisualTreeHelper]::GetChild($obj, $i)) }
        }
      }
    }
    $availWidth = 0.0
    if ($cachedSv) { $availWidth = [double]$cachedSv.ViewportWidth } else { $availWidth = [double]$listView.ActualWidth - 20.0 }
    $totalOther = 0.0
    for ($i = 0; $i -lt $cols.Count - 1; $i++) { $totalOther += [double]$cols[$i].Width }
    $avail = $availWidth - $totalOther - 1.0
    if ($avail -lt 60) { $avail = 60 }
    $last = $cols[$cols.Count - 1]
    if ([Math]::Abs([double]$last.Width - $avail) -gt 0.5) { $last.Width = $avail }
  }.GetNewClosure()
  $listView.Add_LayoutUpdated($handler)
  $listView.Add_SizeChanged($handler)
}

function Show-GuiAboutDialog {
  # Tools > About: author, version, license, unofficial-tool note.
  [xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="About PZ Mod Manager" Width="420" Height="280" WindowStartupLocation="CenterScreen" ResizeMode="NoResize">
  <Grid Margin="16">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>
    <TextBlock Grid.Row="0" Text="PZ Mod Manager" FontSize="20" FontWeight="Bold" Margin="0,0,0,4"/>
    <TextBlock Grid.Row="1" x:Name="AboutVersion" Margin="0,0,0,12"/>
    <TextBlock Grid.Row="2" Text="Created by duy64." Margin="0,0,0,4"/>
    <TextBlock Grid.Row="3" Text="Licensed under the MIT License." Margin="0,0,0,12"/>
    <TextBlock Grid.Row="4" Text="Unofficial fan tool. Not affiliated with Steam, Valve, or The Indie Stone." TextWrapping="Wrap"/>
    <Button Grid.Row="5" x:Name="AboutClose" Content="Close" Width="90" HorizontalAlignment="Right" Padding="10,4"/>
  </Grid>
</Window>
'@
  $reader = New-Object System.Xml.XmlNodeReader $xaml
  $window = [System.Windows.Markup.XamlReader]::Load($reader)
  $window.FindName('AboutVersion').Text = ('Version ' + $ScriptVersion + ' - Project Zomboid B' + $GameBuildFull)
  $window.FindName('AboutClose').Add_Click({ $window.Close() })
  Set-DialogWindowIcon $window
  [void]$window.ShowDialog()
}

function Show-Gui {
  $script:GuiClosedClean = $false
  if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') {
    Write-Host 'GUI needs single-threaded mode (STA). Launch the manager normally (double-click the .bat).' -ForegroundColor Yellow
    return
  }
  try {
    Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase -ErrorAction Stop
  } catch {
    Write-Host 'Could not load WPF (PresentationFramework).' -ForegroundColor Red
    return
  }
  $script:GuiMode = $true
  # Default sort for every tab is Name A-Z; first click on Name goes Z-A.
  $script:GuiModsSortColumn = 'Name'
  $script:GuiModsSortDescending = $false
  $script:GuiPacksSortColumn = 'Name'
  $script:GuiPacksSortDescending = $false
  $script:GuiListsSortColumn = 'Name'
  $script:GuiListsSortDescending = $false
  $script:GuiCategoriesSortColumn = 'Name'
  $script:GuiCategoriesSortDescending = $false
  Write-Host 'Opening GUI...' -ForegroundColor DarkGray
  try {
    Hide-Console
    [xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="PZ Mod Manager" Width="1650" Height="720" MinWidth="720" MinHeight="460" WindowStartupLocation="CenterScreen">
  <Window.Resources>
    <Style x:Key="NoGripperHeader" TargetType="GridViewColumnHeader" BasedOn="{StaticResource {x:Type GridViewColumnHeader}}">
      <Setter Property="Cursor" Value="Arrow"/>
      <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True">
          <Setter Property="Background">
            <Setter.Value>
              <LinearGradientBrush StartPoint="0,0" EndPoint="0,1">
                <GradientStop Color="#E3F7FF" Offset="0"/>
                <GradientStop Color="#BAEAFD" Offset="1"/>
              </LinearGradientBrush>
            </Setter.Value>
          </Setter>
        </Trigger>
      </Style.Triggers>
    </Style>
  </Window.Resources>
  <Grid Margin="10">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>
    <Menu Grid.Row="0" Margin="0,0,0,4" Background="Transparent">
      <MenuItem Header="Tools">
        <MenuItem x:Name="MenuUpdateAll" Header="Check For Mod Updates"/>
        <MenuItem x:Name="MenuCompatReport" Header="Compatibility Report"/>
        <MenuItem x:Name="MenuVariants" Header="Manage Variants"/>
        <MenuItem x:Name="MenuAddInstalled" Header="Add Existing Mods"/>
        <MenuItem x:Name="MenuWorkshop" Header="View Mod's Page"/>
        <MenuItem x:Name="MenuBrowseWorkshop" Header="Workshop Home Page"/>
        <Separator/>
        <MenuItem x:Name="MenuClearCache" Header="Clear Cache"/>
        <Separator/>
        <MenuItem x:Name="MenuAbout" Header="About..."/>
      </MenuItem>
    </Menu>
    <TabControl Grid.Row="1" x:Name="MainTabControl">
      <TabItem Header="Mods">
        <Grid>
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
          </Grid.RowDefinitions>
          <ScrollViewer Grid.Row="0" HorizontalScrollBarVisibility="Auto" VerticalScrollBarVisibility="Disabled" Margin="0,0,0,4">
          <StackPanel Orientation="Horizontal">
            <TextBlock Text="Search:" VerticalAlignment="Center" Margin="0,0,6,0" Width="50"/>
            <TextBox x:Name="SearchBox" Width="260" Margin="0,0,12,0"/>
            <TextBlock Text="Filter by:" VerticalAlignment="Center" Margin="0,0,6,0"/>
            <ComboBox x:Name="CategoryBox" Width="170" Margin="0,0,12,0"/>
            <ComboBox x:Name="PackFilterBox" Width="170" Margin="0,0,12,0"/>
          </StackPanel>
          </ScrollViewer>
          <ScrollViewer Grid.Row="1" HorizontalScrollBarVisibility="Auto" VerticalScrollBarVisibility="Disabled" Margin="0,0,0,8">
          <StackPanel Orientation="Horizontal">
            <TextBlock Text="ID/URL:" VerticalAlignment="Center" Margin="0,0,6,0" Width="50"/>
            <TextBox x:Name="ModAddIdBox" Width="160" Margin="0,0,6,0" VerticalContentAlignment="Center"/>
            <Button x:Name="ModAddButton" Content="Add Mods" Padding="10,4" Margin="0,0,12,0"/>
            <Button x:Name="ModSearchWorkshopButton" Content="Search Workshop" Padding="10,4" Margin="0,0,12,0"/>
            <Button x:Name="ModRemoveFromListButton" Content="Remove Selected From List" Padding="10,4"/>
          </StackPanel>
          </ScrollViewer>
          <ScrollViewer Grid.Row="2" HorizontalScrollBarVisibility="Auto" VerticalScrollBarVisibility="Disabled" Margin="0,0,0,4">
          <StackPanel Orientation="Horizontal">
            <TextBlock Text="Move to:" VerticalAlignment="Center" Margin="0,0,6,0" Width="50"/>
            <ComboBox x:Name="ModMoveCategoryBox" IsEditable="True" Width="200" Margin="0,0,6,0" VerticalContentAlignment="Center"/>
            <Button x:Name="ModMoveToCategoryButton" Content="Move To Category" Padding="10,4" Margin="0,0,12,0"/>
          </StackPanel>
          </ScrollViewer>
          <ScrollViewer Grid.Row="3" HorizontalScrollBarVisibility="Auto" VerticalScrollBarVisibility="Disabled" Margin="0,0,0,8">
          <StackPanel Orientation="Horizontal">
            <Button x:Name="InstallSelectedModsButton" Content="Install Selected" Padding="10,4" Margin="0,0,12,0"/>
            <Button x:Name="UninstallSelectedModsButton" Content="Uninstall Selected" Padding="10,4" Margin="0,0,12,0"/>
          </StackPanel>
          </ScrollViewer>
          <ListView x:Name="ModList" ScrollViewer.HorizontalScrollBarVisibility="Disabled" Grid.Row="4">
            <ListView.View>
              <GridView AllowsColumnReorder="False">
                <GridViewColumn HeaderContainerStyle="{StaticResource NoGripperHeader}" Width="28">
                  <GridViewColumn.Header>
                    <CheckBox Tag="SelectAll" ToolTip="Select all / clear selection" VerticalAlignment="Center" HorizontalAlignment="Center"/>
                  </GridViewColumn.Header>
                  <GridViewColumn.CellTemplate>
                    <DataTemplate>
                      <CheckBox IsChecked="{Binding IsChecked}" VerticalAlignment="Center" HorizontalAlignment="Center"/>
                    </DataTemplate>
                  </GridViewColumn.CellTemplate>
                </GridViewColumn>
                <GridViewColumn Header="Name" Width="450" DisplayMemberBinding="{Binding Name}"/>
                <GridViewColumn Header="Category" Width="150" DisplayMemberBinding="{Binding Category}"/>
                <GridViewColumn Header="Status" Width="150" DisplayMemberBinding="{Binding Status}"/>
                <GridViewColumn Header="Workshop ID" Width="150" DisplayMemberBinding="{Binding WorkshopId}"/>
                <GridViewColumn Header="Installed Date" Width="180" DisplayMemberBinding="{Binding Date}"/>
                <GridViewColumn Header="Size" Width="100" DisplayMemberBinding="{Binding Size}"/>
                <GridViewColumn HeaderContainerStyle="{StaticResource NoGripperHeader}" Header="Packs" Width="200" DisplayMemberBinding="{Binding Packs}"/>
              </GridView>
            </ListView.View>
          </ListView>
        </Grid>
      </TabItem>
      <TabItem Header="Packs">
        <Grid>
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="2*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
          </Grid.RowDefinitions>
          <ScrollViewer Grid.Row="0" HorizontalScrollBarVisibility="Auto" VerticalScrollBarVisibility="Disabled" Margin="0,0,0,4">
          <StackPanel Orientation="Horizontal">
            <TextBlock Text="Search:" VerticalAlignment="Center" Margin="0,0,6,0"/>
            <TextBox x:Name="PackSearchBox" Width="260" Margin="0,0,12,0"/>
          </StackPanel>
          </ScrollViewer>
          <ScrollViewer Grid.Row="1" HorizontalScrollBarVisibility="Auto" VerticalScrollBarVisibility="Disabled" Margin="0,0,0,8">
          <StackPanel Orientation="Horizontal">
            <Button x:Name="NewPackButton" Content="New Pack" Padding="10,4" Margin="0,0,12,0"/>
            <Button x:Name="PackRenameDeleteButton" Content="Rename / Delete" Padding="10,4" Margin="0,0,12,0"/>
          </StackPanel>
          </ScrollViewer>
          <ListView x:Name="PackList" ScrollViewer.HorizontalScrollBarVisibility="Disabled" Grid.Row="2">
            <ListView.View>
              <GridView AllowsColumnReorder="False">
                <GridViewColumn HeaderContainerStyle="{StaticResource NoGripperHeader}" Width="28">
                  <GridViewColumn.Header>
                    <CheckBox Tag="SelectAllPacks" ToolTip="Select all / clear selection" VerticalAlignment="Center" HorizontalAlignment="Center"/>
                  </GridViewColumn.Header>
                  <GridViewColumn.CellTemplate>
                    <DataTemplate>
                      <CheckBox IsChecked="{Binding IsChecked}" VerticalAlignment="Center" HorizontalAlignment="Center"/>
                    </DataTemplate>
                  </GridViewColumn.CellTemplate>
                </GridViewColumn>
                <GridViewColumn Header="Name" Width="280" DisplayMemberBinding="{Binding Name}"/>
                <GridViewColumn Header="Installed" Width="110" DisplayMemberBinding="{Binding Installed}"/>
                <GridViewColumn HeaderContainerStyle="{StaticResource NoGripperHeader}" Header="Description" Width="200" DisplayMemberBinding="{Binding Description}"/>
              </GridView>
            </ListView.View>
          </ListView>
          <ScrollViewer Grid.Row="3" HorizontalScrollBarVisibility="Auto" VerticalScrollBarVisibility="Disabled" Margin="0,8,0,4">
          <StackPanel Orientation="Horizontal">
            <TextBlock x:Name="PackMemberLabel" Text="Mods" FontWeight="Bold" VerticalAlignment="Center" Margin="0,0,12,0"/>
            <TextBox x:Name="PackMemberIdBox" Width="160" Margin="0,0,6,0" VerticalContentAlignment="Center"/>
            <Button x:Name="PackMemberAddButton" Content="Add Mods" Padding="10,4" Margin="0,0,12,0"/>
            <Button x:Name="PackMemberAddFromListButton" Content="Add From List" Padding="10,4" Margin="0,0,12,0"/>
            <Button x:Name="PackMemberRemoveButton" Content="Remove Selected From Pack" Padding="10,4" Margin="0,0,12,0"/>
                        <Button x:Name="PackResetButton" Content="Reset To Built-In Pack" Padding="10,4"/>
          </StackPanel>
          </ScrollViewer>
          <ListView x:Name="PackMemberList" ScrollViewer.HorizontalScrollBarVisibility="Disabled" Grid.Row="4">
            <ListView.View>
              <GridView AllowsColumnReorder="False">
                <GridViewColumn HeaderContainerStyle="{StaticResource NoGripperHeader}" Width="28">
                  <GridViewColumn.Header>
                    <CheckBox Tag="SelectAllPackMembers" ToolTip="Select all / clear selection" VerticalAlignment="Center" HorizontalAlignment="Center"/>
                  </GridViewColumn.Header>
                  <GridViewColumn.CellTemplate>
                    <DataTemplate>
                      <CheckBox IsChecked="{Binding IsChecked}" VerticalAlignment="Center" HorizontalAlignment="Center"/>
                    </DataTemplate>
                  </GridViewColumn.CellTemplate>
                </GridViewColumn>
                <GridViewColumn Header="Name" Width="400" DisplayMemberBinding="{Binding Name}"/>
                <GridViewColumn Header="Category" Width="150" DisplayMemberBinding="{Binding Category}"/>
                <GridViewColumn Header="Status" Width="150" DisplayMemberBinding="{Binding Status}"/>
                <GridViewColumn Header="Installed Date" Width="180" DisplayMemberBinding="{Binding InstalledDate}"/>
                <GridViewColumn Header="Size" Width="100" DisplayMemberBinding="{Binding Size}"/>
                <GridViewColumn HeaderContainerStyle="{StaticResource NoGripperHeader}" Header="Workshop ID" Width="150" DisplayMemberBinding="{Binding WorkshopId}"/>
              </GridView>
            </ListView.View>
          </ListView>
        </Grid>
      </TabItem>
      <TabItem Header="Categories">
        <Grid>
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
          </Grid.RowDefinitions>
          <ScrollViewer Grid.Row="0" HorizontalScrollBarVisibility="Auto" VerticalScrollBarVisibility="Disabled" Margin="0,0,0,4">
          <StackPanel Orientation="Horizontal">
            <TextBlock Text="Search:" VerticalAlignment="Center" Margin="0,0,6,0"/>
            <TextBox x:Name="CategorySearchBox" Width="260" Margin="0,0,12,0"/>

          </StackPanel>
          </ScrollViewer>
          <ScrollViewer Grid.Row="1" HorizontalScrollBarVisibility="Auto" VerticalScrollBarVisibility="Disabled" Margin="0,0,0,8">
          <StackPanel Orientation="Horizontal">
            <Button x:Name="AddCategoryButton" Content="Add Category" Padding="10,4" Margin="0,0,12,0"/>
            <Button x:Name="CategoryRenameDeleteButton" Content="Rename / Delete" Padding="10,4" Margin="0,0,12,0"/>
            <TextBlock Text="Select mods in the Mods tab, then use Move To Category there." VerticalAlignment="Center" Foreground="Gray"/>
          </StackPanel>
          </ScrollViewer>
          <ListView x:Name="CategoryListView" ScrollViewer.HorizontalScrollBarVisibility="Disabled" Grid.Row="2">
            <ListView.View>
              <GridView AllowsColumnReorder="False">
                <GridViewColumn HeaderContainerStyle="{StaticResource NoGripperHeader}" Width="28">
                  <GridViewColumn.Header>
                    <CheckBox Tag="SelectAllCategories" ToolTip="Select all / clear selection" VerticalAlignment="Center" HorizontalAlignment="Center"/>
                  </GridViewColumn.Header>
                  <GridViewColumn.CellTemplate>
                    <DataTemplate>
                      <CheckBox IsChecked="{Binding IsChecked}" VerticalAlignment="Center" HorizontalAlignment="Center"/>
                    </DataTemplate>
                  </GridViewColumn.CellTemplate>
                </GridViewColumn>
                <GridViewColumn Header="Name" Width="300" DisplayMemberBinding="{Binding Name}"/>
                <GridViewColumn HeaderContainerStyle="{StaticResource NoGripperHeader}" Header="Installed" Width="100" DisplayMemberBinding="{Binding Installed}"/>
              </GridView>
            </ListView.View>
          </ListView>
        </Grid>
      </TabItem>
      <TabItem Header="Lists">
        <Grid>
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
          </Grid.RowDefinitions>
          <ScrollViewer Grid.Row="0" HorizontalScrollBarVisibility="Auto" VerticalScrollBarVisibility="Disabled" Margin="0,0,0,4">
          <StackPanel Orientation="Horizontal">
            <TextBlock Text="Search:" VerticalAlignment="Center" Margin="0,0,6,0"/>
            <TextBox x:Name="ListSearchBox" Width="260"/>
          </StackPanel>
          </ScrollViewer>
          <ScrollViewer Grid.Row="1" HorizontalScrollBarVisibility="Auto" VerticalScrollBarVisibility="Disabled" Margin="0,0,0,8">
          <StackPanel Orientation="Horizontal">
            <Button x:Name="NewListButton" Content="New Empty List" Padding="10,4" Margin="0,0,12,0"/>
            <Button x:Name="ListRenameDeleteButton" Content="Rename / Delete" Padding="10,4" Margin="0,0,12,0"/>
            <Button x:Name="SetActiveListButton" Content="Set Active" Padding="10,4" Margin="0,0,12,0"/>
            <Button x:Name="ImportListButton" Content="Import List" Padding="10,4" Margin="0,0,12,0"/>
            <Button x:Name="ExportSelectedListButton" Content="Export Selected List" Padding="10,4"/>
          </StackPanel>
          </ScrollViewer>
          <ListView x:Name="NamedListView" ScrollViewer.HorizontalScrollBarVisibility="Disabled" Grid.Row="2">
            <ListView.View>
              <GridView AllowsColumnReorder="False">
                <GridViewColumn HeaderContainerStyle="{StaticResource NoGripperHeader}" Width="28">
                  <GridViewColumn.Header>
                    <CheckBox Tag="SelectAllLists" ToolTip="Select all / clear selection" VerticalAlignment="Center" HorizontalAlignment="Center"/>
                  </GridViewColumn.Header>
                  <GridViewColumn.CellTemplate>
                    <DataTemplate>
                      <CheckBox IsChecked="{Binding IsChecked}" VerticalAlignment="Center" HorizontalAlignment="Center"/>
                    </DataTemplate>
                  </GridViewColumn.CellTemplate>
                </GridViewColumn>
                <GridViewColumn Header="Name" Width="280" DisplayMemberBinding="{Binding Name}"/>
                <GridViewColumn Header="Created Date" Width="180" DisplayMemberBinding="{Binding Date}"/>
                <GridViewColumn HeaderContainerStyle="{StaticResource NoGripperHeader}" Header="Mods" Width="80" DisplayMemberBinding="{Binding Mods}"/>
              </GridView>
            </ListView.View>
          </ListView>
        </Grid>
      </TabItem>
    </TabControl>
    <TextBlock Grid.Row="2" x:Name="StatusText" Margin="0,8,0,0" Foreground="Gray" TextWrapping="Wrap"/>
  </Grid>
</Window>
'@
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    # Own AppUserModelID, set BEFORE the window is created: without it the
    # taskbar groups this window under PowerShell's AppUserModelID and shows
    # the PowerShell icon no matter what icon is set on the window itself.
    # With its own ID (no shortcut registered under it) the taskbar falls back
    # to the window's own icon (set via WM_SETICON in Set-GuiWindowIcon).
    try {
      $hr = [Win32.ConsoleHider]::SetCurrentProcessExplicitAppUserModelID('PZModManager')
      Write-GuiHideDebug ('appusermodelid: hr=' + $hr)
    } catch {
      Write-GuiHideDebug ('appusermodelid: ERROR ' + $_.Exception.Message)
    }
    $script:GuiWindow = [System.Windows.Markup.XamlReader]::Load($reader)
    Add-NoGripperHandler $script:GuiWindow
    $script:GuiSearchBox = $script:GuiWindow.FindName('SearchBox')
    $script:GuiCategoryBox = $script:GuiWindow.FindName('CategoryBox')
    $script:GuiPackFilterBox = $script:GuiWindow.FindName('PackFilterBox')
    $script:GuiInstallSelectedModsButton = $script:GuiWindow.FindName('InstallSelectedModsButton')
    $script:GuiModMoveCategoryBox = $script:GuiWindow.FindName('ModMoveCategoryBox')
    $script:GuiModMoveToCategoryButton = $script:GuiWindow.FindName('ModMoveToCategoryButton')
    $script:GuiUninstallSelectedModsButton = $script:GuiWindow.FindName('UninstallSelectedModsButton')
    $script:GuiListRenameDeleteButton = $script:GuiWindow.FindName('ListRenameDeleteButton')
    $script:GuiSetActiveListButton = $script:GuiWindow.FindName('SetActiveListButton')
    $script:GuiUpdateAllButton = $script:GuiWindow.FindName('MenuUpdateAll')  # Tools menu item
    $script:GuiClearCacheButton = $script:GuiWindow.FindName('MenuClearCache')  # Tools menu item
    $script:GuiCompatReportButton = $script:GuiWindow.FindName('MenuCompatReport')  # Tools menu item
    $script:GuiVariantsButton = $script:GuiWindow.FindName('MenuVariants')  # Tools menu item
    $script:GuiWorkshopButton = $script:GuiWindow.FindName('MenuWorkshop')  # Tools menu item
    $script:GuiBrowseWorkshopButton = $script:GuiWindow.FindName('MenuBrowseWorkshop')  # Tools menu item
    $script:GuiModAddIdBox = $script:GuiWindow.FindName('ModAddIdBox')
    $script:GuiModAddButton = $script:GuiWindow.FindName('ModAddButton')
    $script:GuiModSearchWorkshopButton = $script:GuiWindow.FindName('ModSearchWorkshopButton')
    $script:GuiModAddInstalledButton = $script:GuiWindow.FindName('MenuAddInstalled')  # Tools menu item
    $script:GuiModRemoveFromListButton = $script:GuiWindow.FindName('ModRemoveFromListButton')
    $script:GuiModList = $script:GuiWindow.FindName('ModList')
    $script:GuiPackList = $script:GuiWindow.FindName('PackList')
    $script:GuiPackMemberList = $script:GuiWindow.FindName('PackMemberList')
    $script:GuiPackMemberLabel = $script:GuiWindow.FindName('PackMemberLabel')
    $script:GuiPackMemberIdBox = $script:GuiWindow.FindName('PackMemberIdBox')
    $script:GuiPackMemberAddButton = $script:GuiWindow.FindName('PackMemberAddButton')
    $script:GuiPackMemberAddFromListButton = $script:GuiWindow.FindName('PackMemberAddFromListButton')
    $script:GuiPackMemberRemoveButton = $script:GuiWindow.FindName('PackMemberRemoveButton')
    $script:GuiPackRenameDeleteButton = $script:GuiWindow.FindName('PackRenameDeleteButton')
    $script:GuiPackResetButton = $script:GuiWindow.FindName('PackResetButton')
    $script:GuiNamedListView = $script:GuiWindow.FindName('NamedListView')
    $script:GuiAddCategoryButton = $script:GuiWindow.FindName('AddCategoryButton')
    $script:GuiCategoryListView = $script:GuiWindow.FindName('CategoryListView')
    $script:GuiCategorySearchBox = $script:GuiWindow.FindName('CategorySearchBox')
    $script:GuiCategoryRenameDeleteButton = $script:GuiWindow.FindName('CategoryRenameDeleteButton')
    $script:GuiNewListButton = $script:GuiWindow.FindName('NewListButton')
    $script:GuiImportListButton = $script:GuiWindow.FindName('ImportListButton')
    $script:GuiExportSelectedListButton = $script:GuiWindow.FindName('ExportSelectedListButton')
    $script:GuiPackSearchBox = $script:GuiWindow.FindName('PackSearchBox')
    $script:GuiListSearchBox = $script:GuiWindow.FindName('ListSearchBox')
    $script:GuiNewPackButton = $script:GuiWindow.FindName('NewPackButton')
    Register-LastColumnFill $script:GuiModList
    Register-LastColumnFill $script:GuiPackList
    Register-LastColumnFill $script:GuiPackMemberList
    Register-LastColumnFill $script:GuiNamedListView
    Register-LastColumnFill $script:GuiCategoryListView
    $script:GuiTabControl = $script:GuiWindow.FindName('MainTabControl')
    $script:GuiStatusText = $script:GuiWindow.FindName('StatusText')
    $script:GuiCategory = 'All categories'
    $script:GuiPackSearch = ''
    $script:GuiListSearch = ''
    $script:GuiSelectedMods = @{}
    $script:GuiSelectedPacks = @{}
    $script:GuiSelectedLists = @{}
    $script:GuiModsShown = 0
    $script:GuiModsInstalled = 0
    $script:GuiModsListName = 'No list'
    $script:GuiPacksShown = 0
    $script:GuiPacksTotal = 0
    $script:GuiListsShown = 0
    $script:GuiListsTotal = 0

    Refresh-GuiCategories
    Refresh-GuiMods
    Refresh-GuiPacks
    Refresh-GuiNamedLists
    Refresh-GuiCategoriesTab

    $debouncedModsSearch = New-GuiDebounce 300 { try { Clear-GuiSelection; Refresh-GuiMods } catch { Write-GuiErrorDump $_ 'ModsSearch' } }
    $script:GuiSearchBox.Add_TextChanged({ & $debouncedModsSearch })
    $script:GuiCategoryBox.Add_SelectionChanged({
      $script:GuiCategory = $script:GuiCategoryBox.SelectedItem
      Clear-GuiSelection; Refresh-GuiMods
    })
    $script:GuiPackFilterBox.Add_SelectionChanged({
      $script:GuiPackFilter = $script:GuiPackFilterBox.SelectedItem
      Clear-GuiSelection; Refresh-GuiMods
    })
    $script:GuiUpdateAllButton.Add_Click({
      Set-GuiBusy $true
      try {
        $script:GuiStatusText.Text = 'Checking for mod updates... (this takes a while, please wait)'
        $script:GuiWindow.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Render, [System.Action]{})
        Update-All
        Refresh-GuiMods
        if ($script:LastUpdateSummary) { Set-GuiTransientStatus ($script:LastUpdateSummary) }
      } finally { Set-GuiBusy $false }
    })
    $script:GuiClearCacheButton.Add_Click({ Clear-GuiCache })
    $script:GuiWindow.FindName('MenuAbout').Add_Click({ Show-GuiAboutDialog })
    $script:GuiCompatReportButton.Add_Click({ Show-GuiCompatibilityReportDialog })
    $script:GuiVariantsButton.Add_Click({ Manage-GuiModVariants })
    $script:GuiWorkshopButton.Add_Click({ Open-GuiWorkshopPage })
    $script:GuiBrowseWorkshopButton.Add_Click({ Start-Process 'https://steamcommunity.com/app/108600/workshop/' })
    $script:GuiModAddButton.Add_Click({ $typed = [string]$script:GuiModAddIdBox.Text; if ($typed.Trim() -ne '') { $entries = @(Parse-ModIdsFromText $typed); if ($entries.Count -gt 0) { $valid = @($entries | Where-Object { [bool]$_.Valid }); $rejected = @($entries | Where-Object { -not [bool]$_.Valid }); if ($valid.Count -gt 0) { Add-GuiListMembers (Get-ActiveListSafe) $valid }; if ($rejected.Count -gt 0) { Show-GuiRejectedWorkshopIds $rejected }; $script:GuiModAddIdBox.Text = '' } else { Set-GuiTransientStatus ('No valid Workshop ID found.') } } else { Set-GuiTransientStatus ('Enter an ID/URL.') } })
    $script:GuiModSearchWorkshopButton.Add_Click({ $res = Show-GuiWorkshopSearch; if ($res.Failed) { Set-GuiTransientStatus ('Could not open Workshop search: ' + [string]$script:LastPickerError); return }; $picked = @($res.Selected); if ($picked.Count -eq 0) { Set-GuiTransientStatus ('Workshop search cancelled.'); return }; Add-GuiListMembers (Get-ActiveListSafe) $picked })
    $script:GuiModAddInstalledButton.Add_Click({ $safe2 = Get-ActiveListSafe; if ($safe2 -eq '') { Set-GuiTransientStatus ('No active list.'); return }; $res = Show-GuiAddInstalledPicker $safe2; if ($res.Failed) { Set-GuiTransientStatus ('Could not open the picker: ' + [string]$script:LastPickerError); return }; $picked = @($res.Selected); if ($picked.Count -eq 0) { if ($res.NoCandidates) { Set-GuiTransientStatus ('Nothing to add - all existing mods are already in this list.'); } else { Set-GuiTransientStatus ('Add existing mods cancelled.'); }; return }; $map2 = Get-InstallMap; $newMap2 = $false; foreach ($e2 in $picked) { if (-not $map2) { $map2 = New-Object PSObject }; if (-not $map2.PSObject.Properties[[string]$e2.WorkshopId]) { $me = New-Object PSObject; $me | Add-Member -NotePropertyName 'installed' -NotePropertyValue $true; $me | Add-Member -NotePropertyName 'folders' -NotePropertyValue @([string]$e2.TopFolder); $me | Add-Member -NotePropertyName 'stamp' -NotePropertyValue (Get-InstalledModStamp (Join-Path $ModsDir ([string]$e2.TopFolder))); $me | Add-Member -NotePropertyName 'installed_on' -NotePropertyValue (Get-Date -Format 'yyyy-MM-dd'); $map2 | Add-Member -NotePropertyName ([string]$e2.WorkshopId) -NotePropertyValue $me -Force; $newMap2 = $true } }; if ($newMap2) { Save-InstallMap $map2 }; Add-GuiListMembers $safe2 $picked })
    $script:GuiModRemoveFromListButton.Add_Click({ Remove-GuiSelectedModsFromList })
    # Mods ListView (GridView): header click sorts (Explorer-style);
    # CheckBox click toggles the shared mod selection. Routed events,
    # attached once - they bubble from the row templates, so no
    # per-row/per-header handlers to wire on every refresh.
    $script:GuiModList.AddHandler([System.Windows.Controls.GridViewColumnHeader]::ClickEvent, [System.Windows.RoutedEventHandler]{
      $src = $args[1].OriginalSource
      if ($src -is [System.Windows.Controls.GridViewColumnHeader]) {
        $col = $src.Column
        if ($col -and $script:GuiModList.View) {
          $idx = $script:GuiModList.View.Columns.IndexOf($col)
          $sortCol = $null
          if ($idx -eq 1) { $sortCol = 'Name' }
          elseif ($idx -eq 2) { $sortCol = 'Category' }
          elseif ($idx -eq 3) { $sortCol = 'Status' }
          elseif ($idx -eq 4) { $sortCol = 'WorkshopId' }
          elseif ($idx -eq 5) { $sortCol = 'Date' }
          elseif ($idx -eq 6) { $sortCol = 'Size' }
          elseif ($idx -eq 7) { $sortCol = 'Packs' }
          if ($sortCol) { Cycle-GuiModsSort $sortCol }
        }
      }
    })
    $script:GuiModList.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, [System.Windows.RoutedEventHandler]{
      $src = $args[1].OriginalSource
      if ($src -is [System.Windows.Controls.CheckBox]) {
        if ([string]$src.Tag -eq 'SelectAll') {
          Toggle-GuiSelectAllMods
        } else {
        $item = $src.DataContext
        if ($item -and [string]$item.WorkshopId -ne '') {
          if (-not $script:GuiSelectedMods) { $script:GuiSelectedMods = @{} }
          if ($src.IsChecked) { $script:GuiSelectedMods[[string]$item.WorkshopId] = [string]$item.Name }
          else { $script:GuiSelectedMods.Remove([string]$item.WorkshopId) }
          $script:GuiSelectionDirty = $true
          Update-GuiSelectionButtons
        }
        }
      }
    })
    $script:GuiModList.Add_SelectionChanged({ Update-GuiWorkshopButtons })
    $script:GuiPackList.AddHandler([System.Windows.Controls.GridViewColumnHeader]::ClickEvent, [System.Windows.RoutedEventHandler]{
      $src = $args[1].OriginalSource
      if ($src -is [System.Windows.Controls.GridViewColumnHeader]) {
        $col = $src.Column
        if ($col -and $script:GuiPackList.View) {
          $idx = $script:GuiPackList.View.Columns.IndexOf($col)
          $sortCol = $null
          if ($idx -eq 1) { $sortCol = 'Name' }
          elseif ($idx -eq 2) { $sortCol = 'Installed' }
          elseif ($idx -eq 3) { $sortCol = 'Description' }
          if ($sortCol) { Cycle-GuiPacksSort $sortCol }
        }
      }
    })
    $script:GuiPackList.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, [System.Windows.RoutedEventHandler]{
      $src = $args[1].OriginalSource
      if ($src -is [System.Windows.Controls.CheckBox]) {
        if ([string]$src.Tag -eq 'SelectAllPacks') { Toggle-GuiSelectAllPacks }
        else {
          $item = $src.DataContext
          if ($item -and [string]$item.Name -ne '') {
            if (-not $script:GuiSelectedPacks) { $script:GuiSelectedPacks = @{} }
            if ($src.IsChecked) { $script:GuiSelectedPacks[[string]$item.Name] = $true } else { $script:GuiSelectedPacks.Remove([string]$item.Name) }
            $script:GuiPackSelectionDirty = $true
            Update-GuiPackSelectionButtons
          }
        }
      }
    })
    $script:GuiPackList.Add_SelectionChanged({
      # A click refreshes the WHOLE Packs tab (top + detail together,
      # from the same snapshot). A detail-only refresh could run
      # against a stale pack set and disagree with the top table
      # (empty detail while top shows members). The re-entrancy guard
      # in Refresh-GuiPacks stops the ItemsSource reset from recursing.
      $item = $script:GuiPackList.SelectedItem
      if ($item -and [string]$item.Name -ne '') {
        $script:GuiPackDetailName = [string]$item.Name
        Refresh-GuiPacks
      }
    })
    $script:GuiPackMemberList.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, [System.Windows.RoutedEventHandler]{
      $src = $args[1].OriginalSource
      if ($src -is [System.Windows.Controls.CheckBox]) {
        if ([string]$src.Tag -eq 'SelectAllPackMembers') { Toggle-GuiSelectAllPackMembers }
        else {
          $item = $src.DataContext
          if ($item -and [string]$item.WorkshopId -ne '') {
            if (-not $script:GuiSelectedMods) { $script:GuiSelectedMods = @{} }
            if ($src.IsChecked) { $script:GuiSelectedMods[[string]$item.WorkshopId] = [string]$item.Name } else { $script:GuiSelectedMods.Remove([string]$item.WorkshopId) }
            $script:GuiSelectionDirty = $true
            Update-GuiPackSelectionButtons
          }
        }
      }
    })
    $script:GuiPackMemberList.AddHandler([System.Windows.Controls.GridViewColumnHeader]::ClickEvent, [System.Windows.RoutedEventHandler]{
      $src = $args[1].OriginalSource
      if ($src -is [System.Windows.Controls.GridViewColumnHeader]) {
        $col = $src.Column
        if ($col -and $script:GuiPackMemberList.View) {
          $idx = $script:GuiPackMemberList.View.Columns.IndexOf($col)
          $sortCol = $null
          if ($idx -eq 1) { $sortCol = 'Name' }
          elseif ($idx -eq 2) { $sortCol = 'Category' }
          elseif ($idx -eq 3) { $sortCol = 'Status' }
          elseif ($idx -eq 4) { $sortCol = 'Date' }
          elseif ($idx -eq 5) { $sortCol = 'Size' }
          elseif ($idx -eq 6) { $sortCol = 'WorkshopId' }
          if ($sortCol) { Cycle-GuiPackMembersSort $sortCol }
        }
      }
    })
    $script:GuiPackMemberList.Add_SelectionChanged({ Update-GuiWorkshopButtons })
    $script:GuiNamedListView.AddHandler([System.Windows.Controls.GridViewColumnHeader]::ClickEvent, [System.Windows.RoutedEventHandler]{
      $src = $args[1].OriginalSource
      if ($src -is [System.Windows.Controls.GridViewColumnHeader]) {
        $col = $src.Column
        if ($col -and $script:GuiNamedListView.View) {
          $idx = $script:GuiNamedListView.View.Columns.IndexOf($col)
          $sortCol = $null
          if ($idx -eq 1) { $sortCol = 'Name' }
          elseif ($idx -eq 2) { $sortCol = 'Mods' }
          if ($sortCol) { Cycle-GuiListsSort $sortCol }
        }
      }
    })
    $script:GuiNamedListView.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, [System.Windows.RoutedEventHandler]{
      $src = $args[1].OriginalSource
      if ($src -is [System.Windows.Controls.CheckBox]) {
        if ([string]$src.Tag -eq 'SelectAllLists') { Toggle-GuiSelectAllLists }
        else {
          $item = $src.DataContext
          if ($item -and [string]$item.Safe -ne '') {
            if (-not $script:GuiSelectedLists) { $script:GuiSelectedLists = @{} }
            if ($src.IsChecked) { $script:GuiSelectedLists[[string]$item.Safe] = $true } else { $script:GuiSelectedLists.Remove([string]$item.Safe) }
            $script:GuiListSelectionDirty = $true
            Update-GuiListSelectionButtons
          }
        }
      }
    })
        $script:GuiCategoryListView.AddHandler([System.Windows.Controls.GridViewColumnHeader]::ClickEvent, [System.Windows.RoutedEventHandler]{
      $src = $args[1].OriginalSource
      if ($src -is [System.Windows.Controls.GridViewColumnHeader]) {
        $col = $src.Column
        if ($col -and $script:GuiCategoryListView.View) {
          $idx = $script:GuiCategoryListView.View.Columns.IndexOf($col)
          $sortCol = $null
          if ($idx -eq 1) { $sortCol = 'Name' }
          elseif ($idx -eq 2) { $sortCol = 'Installed' }
          if ($sortCol) { Cycle-GuiCategoriesSort $sortCol }
        }
      }
    })
    $script:GuiCategoryListView.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, [System.Windows.RoutedEventHandler]{
      $src = $args[1].OriginalSource
      if ($src -is [System.Windows.Controls.CheckBox]) {
        if ([string]$src.Tag -eq 'SelectAllCategories') { Toggle-GuiSelectAllCategories }
        else {
          $item = $src.DataContext
          if ($item -and [string]$item.Name -ne '') {
            if (-not $script:GuiSelectedCategories) { $script:GuiSelectedCategories = @{} }
            if ($src.IsChecked) { $script:GuiSelectedCategories[[string]$item.Name] = $true } else { $script:GuiSelectedCategories.Remove([string]$item.Name) }
            Update-GuiCategorySelectionButtons
          }
        }
      }
    })
    $script:GuiCategoryListView.Add_SelectionChanged({
      # A click refreshes the WHOLE Categories tab (top + detail
      # together, from the same $Mods snapshot). A detail-only refresh
      # could run against a stale $Mods and disagree with the top
      # table (detail 0 while top shows 5). The re-entrancy guard in
      # Refresh-GuiCategoriesTab stops the ItemsSource reset from
      # recursing back in here.
      $item = $script:GuiCategoryListView.SelectedItem
      if ($item -and [string]$item.Name -ne '') {
        $script:GuiCategoryDetailName = [string]$item.Name
        Refresh-GuiCategoriesTab
      }
    })

    $script:GuiInstallSelectedModsButton.Add_Click({ Install-GuiSelectedMods })
    $script:GuiUninstallSelectedModsButton.Add_Click({ Uninstall-GuiSelectedMods })
    $script:GuiModMoveToCategoryButton.Add_Click({ Move-GuiSelectedMods })
    $script:GuiPackMemberAddButton.Add_Click({ $typed = [string]$script:GuiPackMemberIdBox.Text; if ($typed.Trim() -ne '') { $entries = @(Parse-ModIdsFromText $typed); if ($entries.Count -gt 0) { $valid = @($entries | Where-Object { [bool]$_.Valid }); $rejected = @($entries | Where-Object { -not [bool]$_.Valid }); if ($valid.Count -gt 0) { Add-GuiPackMembers $script:GuiPackDetailName $valid }; if ($rejected.Count -gt 0) { Show-GuiRejectedWorkshopIds $rejected }; $script:GuiPackMemberIdBox.Text = '' } else { Set-GuiTransientStatus ('No valid Workshop ID found.') } } else { Set-GuiTransientStatus ('Enter an ID/URL.') } })
    $script:GuiPackMemberAddFromListButton.Add_Click({ $pk = $script:GuiPackDetailName; if ($pk -eq '') { Set-GuiTransientStatus ('Pick a pack first.'); return }; $res = Show-GuiAddFromListPicker $pk; if ($res.Failed) { Set-GuiTransientStatus ('Could not open the picker: ' + [string]$script:LastPickerError); return }; $picked = @($res.Selected); if ($picked.Count -eq 0) { if ($res.NoCandidates) { Set-GuiTransientStatus ('Nothing to add - all list mods are already in this pack.'); } else { Set-GuiTransientStatus ('Add from list cancelled.'); }; return }; Add-GuiPackMembers $pk $picked })
    $script:GuiPackMemberRemoveButton.Add_Click({ Remove-GuiSelectedPackMembers })
    $script:GuiPackRenameDeleteMenu = New-Object System.Windows.Controls.ContextMenu
    $script:GuiPackRenameDeleteRenameItem = New-Object System.Windows.Controls.MenuItem
    $script:GuiPackRenameDeleteRenameItem.Header = 'Rename Selected Pack...'
    $script:GuiPackRenameDeleteRenameItem.Add_Click({
      $pn = @($script:GuiSelectedPacks.Keys)
      if ($pn.Count -eq 1) { Rename-GuiCustomPack $pn[0] }
    })
    [void]$script:GuiPackRenameDeleteMenu.Items.Add($script:GuiPackRenameDeleteRenameItem)
    $script:GuiPackRenameDeleteDescItem = New-Object System.Windows.Controls.MenuItem
    $script:GuiPackRenameDeleteDescItem.Header = 'Edit Pack Description...'
    $script:GuiPackRenameDeleteDescItem.Add_Click({
      $pn = @($script:GuiSelectedPacks.Keys)
      if ($pn.Count -eq 1) { Edit-GuiPackDescription $pn[0] }
    })
    [void]$script:GuiPackRenameDeleteMenu.Items.Add($script:GuiPackRenameDeleteDescItem)
    $script:GuiPackRenameDeleteDeleteItem = New-Object System.Windows.Controls.MenuItem
    $script:GuiPackRenameDeleteDeleteItem.Header = 'Delete Selected Packs'
    $script:GuiPackRenameDeleteDeleteItem.Add_Click({ Delete-GuiSelectedPacks })
    [void]$script:GuiPackRenameDeleteMenu.Items.Add($script:GuiPackRenameDeleteDeleteItem)
    $script:GuiPackRenameDeleteMenu.Add_Opened({
      # Rename and Edit Description need exactly one checked pack;
      # Delete needs at least one. Built-in packs are included -
      # renaming or deleting one applies to the active list only.
      $npk = 0
      if ($script:GuiSelectedPacks) { $npk = $script:GuiSelectedPacks.Count }
      $script:GuiPackRenameDeleteRenameItem.IsEnabled = ($npk -eq 1)
      $script:GuiPackRenameDeleteDescItem.IsEnabled = ($npk -eq 1)
      $script:GuiPackRenameDeleteDeleteItem.IsEnabled = ($npk -gt 0)
      $script:GuiPackRenameDeleteDeleteItem.Header = ('Delete selected packs (' + $npk + ')')
    })
    $script:GuiPackRenameDeleteButton.ContextMenu = $script:GuiPackRenameDeleteMenu
    $script:GuiPackRenameDeleteButton.Add_Click({ $script:GuiPackRenameDeleteButton.ContextMenu.IsOpen = $true })
    $script:GuiPackResetButton.Add_Click({ Reset-GuiCustomPack $script:GuiPackDetailName })
    $script:GuiCategoryRenameDeleteMenu = New-Object System.Windows.Controls.ContextMenu
    $script:GuiCategoryRenameItem = New-Object System.Windows.Controls.MenuItem
    $script:GuiCategoryRenameItem.Header = 'Rename Selected Category...'
    $script:GuiCategoryRenameItem.Add_Click({
      $cn = @($script:GuiSelectedCategories.Keys)
      if ($cn.Count -eq 1) { Rename-GuiCategory $cn[0] }
    })
    [void]$script:GuiCategoryRenameDeleteMenu.Items.Add($script:GuiCategoryRenameItem)
    $script:GuiCategoryDeleteItem = New-Object System.Windows.Controls.MenuItem
    $script:GuiCategoryDeleteItem.Header = 'Delete Selected Categories'
    $script:GuiCategoryDeleteItem.Add_Click({ Delete-GuiSelectedCategories })
    [void]$script:GuiCategoryRenameDeleteMenu.Items.Add($script:GuiCategoryDeleteItem)
    $script:GuiCategoryRenameDeleteMenu.Add_Opened({
      $nc2 = 0
      if ($script:GuiSelectedCategories) { $nc2 = $script:GuiSelectedCategories.Count }
      $script:GuiCategoryRenameItem.IsEnabled = ($nc2 -eq 1)
      $script:GuiCategoryDeleteItem.IsEnabled = ($nc2 -gt 0)
      $script:GuiCategoryDeleteItem.Header = ('Delete selected categories (' + $nc2 + ')')
    })
    $script:GuiCategoryRenameDeleteButton.ContextMenu = $script:GuiCategoryRenameDeleteMenu
    $script:GuiCategoryRenameDeleteButton.Add_Click({ $script:GuiCategoryRenameDeleteButton.ContextMenu.IsOpen = $true })

    $script:GuiListRenameDeleteMenu = New-Object System.Windows.Controls.ContextMenu
    $script:GuiListRenameDeleteRenameItem = New-Object System.Windows.Controls.MenuItem
    $script:GuiListRenameDeleteRenameItem.Header = 'Rename Selected...'
    $script:GuiListRenameDeleteRenameItem.Add_Click({ Rename-GuiSelectedList })
    [void]$script:GuiListRenameDeleteMenu.Items.Add($script:GuiListRenameDeleteRenameItem)
    $script:GuiListRenameDeleteDeleteItem = New-Object System.Windows.Controls.MenuItem
    $script:GuiListRenameDeleteDeleteItem.Header = 'Delete Selected'
    $script:GuiListRenameDeleteDeleteItem.Add_Click({ Delete-GuiSelectedLists })
    [void]$script:GuiListRenameDeleteMenu.Items.Add($script:GuiListRenameDeleteDeleteItem)
    $script:GuiListRenameDeleteMenu.Add_Opened({
      $ln = 0
      if ($script:GuiSelectedLists) { $ln = $script:GuiSelectedLists.Count }
      $script:GuiListRenameDeleteRenameItem.IsEnabled = ($ln -eq 1)
      $script:GuiListRenameDeleteDeleteItem.IsEnabled = ($ln -gt 0)
      $script:GuiListRenameDeleteDeleteItem.Header = ('Delete selected (' + $ln + ')')
    })
    $script:GuiListRenameDeleteButton.ContextMenu = $script:GuiListRenameDeleteMenu
    $script:GuiListRenameDeleteButton.Add_Click({ $script:GuiListRenameDeleteButton.ContextMenu.IsOpen = $true })
    $script:GuiSetActiveListButton.Add_Click({ Set-GuiActiveList })
    $script:GuiNewListButton.Add_Click({ New-GuiNamedList })
    $script:GuiImportListButton.Add_Click({ Import-GuiList })
    $script:GuiExportSelectedListButton.Add_Click({ Export-GuiList })
    $debouncedPacksSearch = New-GuiDebounce 300 { try { $script:GuiPackSearch = $script:GuiPackSearchBox.Text; Clear-GuiSelection; Refresh-GuiPacks } catch { Write-GuiErrorDump $_ 'PacksSearch' } }
    $script:GuiPackSearchBox.Add_TextChanged({ & $debouncedPacksSearch })
    $debouncedListsSearch = New-GuiDebounce 300 { try { $script:GuiListSearch = $script:GuiListSearchBox.Text; Clear-GuiSelection; Refresh-GuiNamedLists } catch { Write-GuiErrorDump $_ 'ListsSearch' } }
    $script:GuiListSearchBox.Add_TextChanged({ & $debouncedListsSearch })
    $debouncedCatsSearch = New-GuiDebounce 300 { try { $script:GuiCategorySearch = $script:GuiCategorySearchBox.Text; Clear-GuiSelection; Refresh-GuiCategoriesTab } catch { Write-GuiErrorDump $_ 'CategoriesSearch' } }
    $script:GuiCategorySearchBox.Add_TextChanged({ & $debouncedCatsSearch })
    $script:GuiTabControl.Add_SelectionChanged({
      if ($script:GuiSelectionDirty) {
        $script:GuiSelectionDirty = $false
        $idx = $script:GuiTabControl.SelectedIndex
        if ($idx -eq 0) { Refresh-GuiMods }
        elseif ($idx -eq 1) { Refresh-GuiPacks }
        elseif ($idx -eq 2) { Refresh-GuiCategoriesTab }
      }
      if ($script:GuiPackSelectionDirty) {
        $script:GuiPackSelectionDirty = $false
        if ($script:GuiTabControl.SelectedIndex -eq 1) { Refresh-GuiPacks }
      }
      if ($script:GuiListSelectionDirty) {
        $script:GuiListSelectionDirty = $false
        if ($script:GuiTabControl.SelectedIndex -eq 3) { Refresh-GuiNamedLists }
      }
      Update-GuiStatusBar
    })
    $script:GuiNewPackButton.Add_Click({ New-GuiCustomPack })
    $script:GuiAddCategoryButton.Add_Click({ Add-GuiCategory })


    # Final button-state pass: the startup refresh ran before some
    # buttons were wired (View on Workshop), so re-apply the
    # selection gates now that every button is assigned.
    Update-GuiSelectionButtons
    Update-GuiPackSelectionButtons
    Update-GuiCategorySelectionButtons
    Update-GuiListSelectionButtons
    Update-GuiWorkshopButtons
    $script:GuiWindow.Title = 'PZ Mod Manager v' + $ScriptVersion + ' - Project Zomboid B' + $GameBuildFull
    Set-GuiWindowIcon
    if ($script:StartupAdoptSummary) { Set-GuiTransientStatus $script:StartupAdoptSummary 15 }
    [void]$script:GuiWindow.ShowDialog()
    $script:GuiClosedClean = $true
    if ($script:GuiIcon) { try { $script:GuiIcon.Dispose() } catch { }; $script:GuiIcon = $null }
  } catch {
    Show-Console
    $err = $_
    Write-GuiErrorDump $err 'Show-Gui'
    $script:GuiMode = $false
    Write-Host ('GUI error: ' + $err.Exception.Message) -ForegroundColor Red
    Pause
  } finally {
    $script:GuiMode = $false
  }
}

# Confirm the game build before anything uses $GameBuild (default 42, version.txt check, prompt on mismatch).
$resolvedBuild = Resolve-GameBuild
$GameBuild = $resolvedBuild.Build
$GameBuildFull = $resolvedBuild.Full
$GameBuildMinor = $resolvedBuild.Minor

Repair-GenericModFolders
Repair-FlattenedMods
Repair-ManagerShortcut

# GUI-only since v234: the text menu was removed. Its features live in the
# Mods tab (Clear cache) and the Lists tab.
Show-Gui