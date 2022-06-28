REM This will need to have the latest version of imagemagick installed on your Windows PC
REM https://imagemagick.org/script/download.php#windows
REM 1 - Create a folder with the jpg files you want to process and place this cmd in that same directory
REM 2 - Run process_tcards.cmd
REM 3 - Original files will not be touched and results are stored in results subfolder and the grayscale subfolder

mkdir resize
mkdir resize_stretch
mkdir blur
mkdir soften
mkdir results
mkdir grayscale

magick mogrify -resize 3200x1800 -path .\resize *.jpg
magick mogrify -format png -path .\resize .\resize\*.jpg
del .\resize\*.jpg
magick mogrify -resize 3200!x1800! -path .\resize_stretch *.jpg
magick mogrify -blur 0x16 -path .\blur .\resize_stretch\*.jpg
magick mogrify -format png .\blur\*.jpg
del .\blur\*.jpg
magick mogrify -alpha set -background None -virtual-pixel VerticalTile -channel A -blur 0x100  -level 50%,100% +channel -path .\soften .\resize\*.png
REM for /F %i in ('dir /b .\blur\*.png') do magick -gravity center .\blur\%i .\soften\%i -composite .\results\%i
for /F %%i in ('dir /b .\blur\*.png') do magick -gravity center .\blur\%%i .\soften\%%i -composite .\results\%%i
magick mogrify -colorspace gray -path .\grayscale .\results\*.png