####################################################
# create_poster.ps1
# v1.0
# author: bullmoose20
#
# DESCRIPTION: 
# In a powershell window and with ImageMagick installed, this will 
# 1 - create a 2000x3000 colored poster based on $base_color parameter otherwise a random color for base is used and creates base_$base_color.jpg
# 2 - it will add the gradient in the second line to create a file called gradient_$base_color.jpg
# 3 - takes the $logo specified and sizes it 1800px (or whatever desired logo_size specified) wide leaving 100 on each side as a buffer of space
# 4 - if a border is specified, both color and size of border will be applied
# 5 - if text is desired it will be added to the final result with desired size, color and font
# 6 - if white-wash is enabled, the colored logo with be made to 100% white
# 7 - final results are a logo centered and merged to create a 2000x3000 poster with the $base_color color and gradient fade applied and saved as a jpg file (with an optional border of specified width and color and logo offset, as well as text, font, font_color, and font_size )
# 
# REQUIREMENTS:
# Imagemagick must be installed - https://imagemagick.org/script/download.php
# font must be installed on system and visible by Imagemagick. Make sure that you install the ttf font for ALL users as an admin so ImageMagick has access to the font when running (r-click on font Install for ALL Users in Windows)
# Powershell security settings: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-7.2
#
# PARAMETERS:
# -logo          (specify the logo/image png file that you want to have centered and resized)
# -logo_offset   (+100 will push logo down 100 px from the center. -100 will move the logo up 100px from the center. Value is between -1500 and 1500. DEFAULT=0 or centered. -750 is the midpoint between the center and the top)
# -logo_resize   (1000 will resize the log to fit in the poster.DEFAULT=1800.)
# -base_color    (hex color code for the base background. If omitted a random color will be picked using the "#xxxxxx" format)
# -text          (text that you want to show on the resulting image. use \n to perform a carriage return and enclose text in double quotes.)
# -text_offset   (+100 will push text down 100 px from the center. -100 will move the text up 100px from the center. Value is between -1500 and 1500. DEFAULT=0 or centered. +750 is the midpoint between the center and the bottom)
# -font          (font name that you want to use. magick identify -list font magick -list font)
# -font_color    (hex color code for the font. If omitted, white or #FFFFFF will be used)
# -font_size     (default is 250. pick a font size between 10-500.)
# -border        (default is 0 or $false - boolean value and when set to 1 or $true, it will add the border)
# -border_width  (width in pixels between 1 and 100. DEFAULT=15)
# -border_color  (hex color code for the border color using the "#xxxxxx" format. DEFAULT=#FFFFFF)
# -white_wash    (default is 0 or $false - boolean value and when set to 1 or $true, it will take the logo and make it white)
# -clean         (default is 0 or $false - boolean value and when set to 1 or $true, it will delete the temporary files that are created as part of the script)
#
####################################################

param ($logo,$logo_offset,$logo_resize,$base_color,$text,$text_offset,$font,$font_color,$font_size,[bool]$border,$border_width,$border_color,[bool]$white_wash,[bool]$clean)

###########################################
# VALIDATE params and set default params
###########################################
$script_path = $PSScriptRoot
write-host "Script path   : $script_path"

#################################
# $logo checks
#################################
if ($logo -eq "" -or $logo -eq $null) {
  magick -size 1x1 xc:none transparent.png
  $logo="transparent.png"
}

if( -not [IO.Path]::IsPathRooted($logo) )
{
    $logo = Join-Path -Path (Get-Location).Path -ChildPath $logo
}
$logo = Join-Path -Path $logo -ChildPath '.'
$logo = [IO.Path]::GetFullPath($logo)
$orig_logo = $logo

write-host "Logo path     : $logo"

if (-not(Test-Path -Path $logo -PathType Leaf)) {
  write-host "Logo >$logo< not found. Exiting now..." -ForegroundColor Red -BackgroundColor White
  exit
}

#################################
# $Fade-Gradient.png checks
#################################
$fade="Fade-Gradient.png"
if (-not(Test-Path -Path $fade -PathType Leaf)) {
  write-host "File >$fade< not found. Creating now. Please standby..." -ForegroundColor Red -BackgroundColor White
  magick -size 6500x6500 gradient:none-black -rotate +45 -gravity center -crop 2000x3000+0-2000 +repage gradient_diagonal.png
  magick gradient_diagonal.png -level 0%,100%,0.5 gradient_diagonal.png
  magick -size 2000x3000 xc:black `( -size 2000x3000 radial-gradient:"gray(5%)-gray(45%)" `) -alpha off -compose copy_opacity -composite gray_rad_grad.png
  magick gradient_diagonal.png gray_rad_grad.png -background None -layers Flatten Fade-Gradient.png
  if (Test-Path gradient_diagonal.png) {
    Remove-Item -Path gradient_diagonal.png -Force | Out-Null
  }
  if (Test-Path gray_rad_grad.png) {
    Remove-Item -Path gray_rad_grad.png -Force | Out-Null
  }
}
$fade=resolve-path $fade
write-host "Fade path     : $fade"

#################################
# $base_color checks
#################################

if ($base_color -eq "" -or $base_color -eq $null) {
  $base_color=("#{0:X6}" -f (Get-Random -Maximum 0xFFFFFF))
}

if($base_color.StartsWith('#','CurrentCultureIgnoreCase')) {
} else {
     $X="#"+$base_color.Substring(0,6)
     $X=$X.Trim()
     Write-Host "Base color parameter >$base_color< is missing '#'. Should be something like $X. Exiting now..." -ForegroundColor Red -BackgroundColor White
     exit
}

if($base_color.Substring(1).length -eq 6){
} else {
     if($base_color.Length -lt 7) {
          $X=$base_color.Substring(0,$base_color.Length)
     } else {
          $X=$base_color.Substring(0,7)
     }
     $X=$X.Trim()
     Write-Host "Base color parameter >$base_color< is ("$base_color.Substring(1).length") not 6 characters long. Should be something like $X. Exiting now..." -ForegroundColor Red -BackgroundColor White
     exit
}

$Y = $base_color.Substring(1).length
if($base_color.Substring(1) -match "[0123456789abcdefABCDEF]{$Y}"){
} else {
     $tmp=("#{0:X6}" -f (Get-Random -Maximum 0xFFFFFF))
     Write-Host "Base color parameter >$base_color< is not HEX. Should be something like $tmp. Exiting now..." -ForegroundColor Red -BackgroundColor White
     exit
}

#################################
# $font checks
#################################
$tmpfont=$font+"$"
$chkfont=magick identify -list font | Select-String "Font: $tmpfont"

if ($chkfont -eq "" -or $chkfont -eq $null) {
     $font_list=magick identify -list font | Select-String "Font: "
     $font_list -replace "  Font: ",""> magick_fonts.txt
     Write-Host "Font parameter >$font< is not installed/found. List of installed fonts that Imagemagick can use was listed and exported to here: magick_fonts.txt. Random Font mode enabling now..." -ForegroundColor Red -BackgroundColor White
     write-host $font_list.count " fonts are visible to Imagemagick. Picking random font and continuing..."
     if ($font_list.count -gt 0) {
         if (Test-Path magick_fonts.txt) {
             $font=Get-Random -InputObject (get-content magick_fonts.txt)
             Write-Host "This font >$font< was randomly selected."
         } else {
             # File not found
             $font=""
         }
     } else {
         # 0 fonts found
         $font=""
     }
}

if ($font -eq "" -or $font -eq $null) {
  write-host "No fonts found. Aborting..."
  exit
}

#################################
# $font_color checks
#################################

if ($font_color -eq "" -or $font_color -eq $null) {
  $font_color="#FFFFFF"
}

if($font_color.StartsWith('#','CurrentCultureIgnoreCase')) {
} else {
     $X="#"+$font_color.Substring(0,6)
     $X=$X.Trim()
     Write-Host "Font Color parameter >$font_color< is missing '#'. Should be something like $X. Exiting now..." -ForegroundColor Red -BackgroundColor White
     exit
}

if($font_color.Substring(1).length -eq 6){
} else {
     if($font_color.Length -lt 7) {
          $X=$font_color.Substring(0,$font_color.Length)
     } else {
          $X=$font_color.Substring(0,7)
     }
     $X=$X.Trim()
     Write-Host "Font color parameter >$font_color< is ("$font_color.Substring(1).length") not 6 characters long. Should be something like $X. Exiting now..." -ForegroundColor Red -BackgroundColor White
     exit
}

$Y = $font_color.Substring(1).length
if($font_color.Substring(1) -match "[0123456789abcdefABCDEF]{$Y}"){
} else {
     $tmp=("#{0:X6}" -f (Get-Random -Maximum 0xFFFFFF))
     Write-Host "Font color parameter >$font_color< is not HEX. Should be something like $tmp. Exiting now..." -ForegroundColor Red -BackgroundColor White
     exit
}

#################################
# $border_width checks
#################################
if ($border_width -eq "" -or $border_width -eq $null) {
  $border_width=15
}

if (($border_width -gt 100) -or ($border_width -lt 1)) {
  Write-Host "Border width should be between 1 and 100. You have>$border_width<. Setting border_width to default value of 15." -ForegroundColor Red -BackgroundColor White
  $border_width=15
}

#################################
# $font_size checks
#################################
if ($font_size -eq "" -or $font_size -eq $null) {
  $font_size=250
}

if (($font_size -gt 500) -or ($font_size -lt 10)) {
  Write-Host "Font size should be between 10 and 500. You have>$font_size<. Setting font_size to default value of 250." -ForegroundColor Red -BackgroundColor White
  $font_size=250
}

#################################
# $border_color checks
#################################
if ($border_color -eq "" -or $border_color -eq $null) {
  $border_color="#FFFFFF"
}

if($border_color.StartsWith('#','CurrentCultureIgnoreCase')) {
} else {
     $X="#"+$border_color.Substring(0,6)
     $X=$X.Trim()
     Write-Host "Border color parameter >$border_color< is missing '#'. Should be something like $X. Exiting now..." -ForegroundColor Red -BackgroundColor White
     exit
}

if($border_color.Substring(1).length -eq 6){
} else {
     $X=$border_color.Substring(0,7)
     $X=$X.Trim()
     Write-Host "Border color parameter >$border_color< is ("$border_color.Substring(1).length") not 6 characters long. Should be something like $X. Exiting now..." -ForegroundColor Red -BackgroundColor White
     exit
}

$Y = $border_color.Substring(1).length
if($border_color.Substring(1) -match "[0123456789abcdefABCDEF]{$Y}"){
} else {
     $tmp=("#{0:X6}" -f (Get-Random -Maximum 0xFFFFFF))
     Write-Host "Border color parameter >$border_color< is not HEX. Should be something like $tmp. Exiting now..." -ForegroundColor Red -BackgroundColor White
     exit
}

#################################
# $logo_offset checks
#################################
if ($logo_offset -eq "" -or $logo_offset -eq $null) {
  $logo_offset="+0"
}

$logo_offset=$logo_offset.ToString()

if($logo_offset.StartsWith('-','CurrentCultureIgnoreCase') -or $logo_offset.StartsWith('+','CurrentCultureIgnoreCase') ) {
} else {
     Write-Host "Logo Offset parameter is missing '+' or '-'. Exiting now..." -ForegroundColor Red -BackgroundColor White
     exit
}

if($logo_offset.Substring(1) -match "^-?\d+$") {
} else {
     Write-Host "Logo Offset parameter is not numeric. Exiting now..." -ForegroundColor Red -BackgroundColor White
     exit
}

if ($logo_offset.Substring(1) -In -1500..1500) {
} else {
  Write-Host "Logo Offset parameter is"$logo_offset.Substring(1)"which is NOT between -1500 and 1500. Exiting now..." -ForegroundColor Red -BackgroundColor White
  exit
}

#################################
# $logo_resize checks
#################################

if ($logo_resize -eq "" -or $logo_resize -eq $null) {
  $logo_resize="1800"
}

if ($logo_resize -In 1..1800) {
} else {
  Write-Host "Logo resize parameter is>$logo_resize<which is NOT between 1 and 1800. Exiting now..." -ForegroundColor Red -BackgroundColor White
  exit
}

#################################
# $text_offset checks
#################################
if ($text_offset -eq "" -or $text_offset -eq $null) {
  $text_offset="+0"
}

$text_offset=$text_offset.ToString()

if($text_offset.StartsWith('-','CurrentCultureIgnoreCase') -or $text_offset.StartsWith('+','CurrentCultureIgnoreCase') ) {
} else {
     Write-Host "Text Offset parameter is missing '+' or '-'. Exiting now..." -ForegroundColor Red -BackgroundColor White
     exit
}

if($text_offset.Substring(1) -match "^-?\d+$") {
} else {
     Write-Host "Text Offset parameter is not numeric. Exiting now..." -ForegroundColor Red -BackgroundColor White
     exit
}

if ($text_offset.Substring(1) -In -1500..1500) {
} else {
  Write-Host "Text Offset parameter is>"$text_offset.Substring(1)"<which is NOT between -1500 and 1500. Exiting now..." -ForegroundColor Red -BackgroundColor White
  exit
}

#################################
# MAIN
#################################
$noextension = (Get-Item $logo).BaseName
$extension = [System.IO.Path]::GetExtension($logo)

#################################
# collect paths
#################################
$tmp_path=Join-Path -Path $script_path -ChildPath "tmp"
$out_path=Join-Path -Path $script_path -ChildPath "output"
$logo=Join-Path -Path 'tmp' -ChildPath "$noextension$extension"
$bcf=Join-Path -Path 'tmp' -ChildPath "base_$base_color.jpg"
$gbcf=Join-Path -Path 'tmp' -ChildPath "gradient_$base_color.jpg"
$wf=Join-Path -Path 'tmp' -ChildPath "white_$noextension$extension"
$rf=Join-Path -Path 'tmp' -ChildPath "resized_$noextension$extension"
$nef=Join-Path -Path 'tmp' -ChildPath "$noextension.jpg"
$nebcf=Join-Path -Path 'tmp' -ChildPath "$noextension-$base_color.jpg"
$of=Join-Path -Path 'output' -ChildPath "$noextension-$base_color.jpg"

# Create dirs
New-Item -ItemType Directory -Force -Path $tmp_path  | Out-Null
New-Item -ItemType Directory -Force -Path $out_path | Out-Null

# Copy logo to tmp location
Copy-Item -Path $orig_logo -Destination $logo

#################################
# output information about run
#################################

$mywidth=2000-(2*$border_width)
$myheight=3000-(2*$border_width)
$tmp_resize="$mywidth" + "x" + "$myheight!"
$tmp_border="$border_width" + "x" + "$border_width"

write-host "base color    : $base_color"
write-host "logo offset   : $logo_offset"
write-host "logo resize   : $logo_resize"
write-host "white-wash    : $white_wash"
if ($text -eq "" -or $text -eq $null) {
} else {
write-host "text          : $text"
write-host "text offset   : $text_offset"
write-host "font          : $font"
write-host "font color    : $font_color"
write-host "font size     : $font_size"
}
write-host "border        : $border"
if ($border) {
  write-host "border color  : $border_color"
  write-host "border width  : $border_width"
  write-host "resize width  : $mywidth"
  write-host "resize height : $myheight"
}
write-host "input logo    : $noextension$extension"
write-host "output file   : $noextension.jpg"
write-host "clean         : $clean"

#################################
# creation of image begins
#################################

#write-host "magick -size 2000x3000 xc:$base_color $bcf"
magick -size 2000x3000 xc:$base_color $bcf
#write-host "magick -gravity center $bcf $fade -background None -layers Flatten $gbcf"
magick -gravity center $bcf $fade -background None -layers Flatten $gbcf
#write-host "magick $logo -colorspace gray -fill white -colorize 100 $wf"
magick $logo -colorspace gray -fill white -colorize 100 $wf

$tmplogo=resolve-path $logo
if ($white_wash) {
  $logo=Join-Path -Path 'tmp' -ChildPath "white_$noextension$extension"
}

#write-host "magick $logo -resize $logo_resize PNG32:$rf"
magick $logo -resize $logo_resize PNG32:$rf 
#write-host "magick $gbcf -set colorspace sRGB $rf -gravity center -geometry +0$logo_offset -composite $nef"
magick $gbcf -set colorspace sRGB $rf -gravity center -geometry +0$logo_offset -composite $nef

if ($text -eq "" -or $text -eq $null) {
} else {
  #write-host "magick $nef -gravity center -background None -layers Flatten `( -font $font -pointsize $font_size -fill $font_color -size 1900x1000 -background none caption:$text -trim -gravity center -extent 1900x1000 `) -gravity center -geometry +0$text_offset -composite $nef"
  magick $nef -gravity center -background None -layers Flatten `( -font $font -pointsize $font_size -fill $font_color -size 1900x1000 -background none caption:"$text" -trim -gravity center -extent 1900x1000 `) -gravity center -geometry +0$text_offset -composite $nef
}

if ($border) {
  #write-host "magick $nef -resize $tmp_resize $nef"
  magick $nef -resize $tmp_resize $nef
  #write-host "magick $nef -bordercolor $border_color -border $tmp_border $nef"
  magick $nef -bordercolor "$border_color" -border $tmp_border $nef
}

#################################
# move final result from tmp to ..\
#################################
Move-Item -Path $nef -Destination $of -Force | Out-Null
if (Test-Path $of) {
  Write-Host "File saved to: $of"
}
Write-Host ""

#################################
# clean
#################################
if ($clean) {
  if (Test-Path $logo) {
    Remove-Item -Path $logo -Force | Out-Null
  }
  if (Test-Path $tmplogo) {
    Remove-Item -Path $tmplogo -Force | Out-Null
  }
  if (Test-Path $bcf) {
    Remove-Item -Path $bcf -Force | Out-Null
  }
  if (Test-Path $gbcf) {
    Remove-Item -Path $gbcf -Force | Out-Null
  }
  if (Test-Path $rf) {
    Remove-Item -Path $rf -Force | Out-Null
  }
  if (Test-Path $wf) {
    Remove-Item -Path $wf -Force | Out-Null
  }
}
