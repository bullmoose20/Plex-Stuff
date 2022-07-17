#!/bin/bash
IFS=$'\n'

log=log_file.txt
logConverted=logConverted_file.txt
logToConvert=logToConvert_file.txt

# create log file
printf "Log File - " >> $log
printf "Log File - " >> $logConverted
printf "Log File - " >> $logToConvert
pwd >> $logConverted
pwd >> $logToConvert

# append date to log file
date >> $log
date >> $logConverted
date >> $logToConvert

COUNTER=0
COUNTERtoConvert=0
COUNTERConverted=0
COUNTLow=0
COUNT480p=0
COUNT720p=0
COUNT1080p=0
COUNT2160p=0
COUNT8K=0
COUNTNA=0
ffprobe_path='/usr/lib/jellyfin-ffmpeg/ffprobe'

# Reset
Color_Off='\033[0m'       # Text Reset

# Regular Colors
Black='\033[0;30m'        # Black
Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
Yellow='\033[0;33m'       # Yellow
Blue='\033[0;34m'         # Blue
Purple='\033[0;35m'       # Purple
Cyan='\033[0;36m'         # Cyan
White='\033[0;37m'        # White

# Bold
BBlack='\033[1;30m'       # Black
BRed='\033[1;31m'         # Red
BGreen='\033[1;32m'       # Green
BYellow='\033[1;33m'      # Yellow
BBlue='\033[1;34m'        # Blue
BPurple='\033[1;35m'      # Purple
BCyan='\033[1;36m'        # Cyan
BWhite='\033[1;37m'       # White

# Underline
UBlack='\033[4;30m'       # Black
URed='\033[4;31m'         # Red
UGreen='\033[4;32m'       # Green
UYellow='\033[4;33m'      # Yellow
UBlue='\033[4;34m'        # Blue
UPurple='\033[4;35m'      # Purple
UCyan='\033[4;36m'        # Cyan
UWhite='\033[4;37m'       # White

# Background
On_Black='\033[40m'       # Black
On_Red='\033[41m'         # Red

##Search in Windows Ext: .mkv OR Ext: .mp4 OR Ext: .wmv OR Ext: .flv OR Ext: .webm OR Ext: .mov OR Ext: .avi OR Ext: .m4v OR Ext: .divx OR Ext: .mts OR Ext: .m2ts OR Ext: .mpg
VideoFiles=$(find ./ -maxdepth 10 -regex ".*\.\(mkv\|mp4\|wmv\|flv\|webm\|mov\|avi\|m4v\|divx\|mts\|m2ts\|mpg\)");


#######################################
for i in $VideoFiles
do
  let COUNTER++
  filename=$(basename "$i");
  extension="${filename##*.}";
  filename="${filename%.*}";
echo -e "${UGreen}############################################################################################################################################################################${Color_Off}\n";
echo -e "${Color_Off}Getting info of ${BCyan}$i${Color_Off}";
echo -e "$ffprobe_path -v quiet -show_format -of flat=s=_ -show_entries stream=height,width,nb_frames,duration,codec_name -sexagesimal "$i")";
# echo -e "eval $(ffprobe -v quiet -show_format -of flat=s=_ -show_entries stream=height,width,nb_frames,duration,codec_name -sexagesimal "$i");"
    eval $($ffprobe_path -v quiet -show_format -of flat=s=_ -show_entries stream=height,width,nb_frames,duration,codec_name -sexagesimal "$i");
    width=${streams_stream_0_width};
    height=${streams_stream_0_height};
    bitrate=${format_bit_rate};
    duration=${format_duration};
	codec=${streams_stream_0_codec_name};
	#kbitrate=$((bitrate/1000));
    #duration=$((durationSec/60));
    d=$(dirname "$i")
echo -e "${Color_Off}Duration = ${URed}$duration ${Color_Off}, Height/Width = ${URed}$height/$width, ${Color_Off} Bitrate =${URed} $bitrate${Color_Off}, Codec =${URed} $codec${Color_Off}\n";
echo -e "${UGreen}############################################################################################################################################################################${Color_Off}";
### mkdir $d/Processed;

if ((1<= $height &&  $height<=400))
then
    let COUNTLow++
    desired="200k";
    min="100k";
    max="800k";
    echo -e "This is a ${URed}LOW Quality${Color_Off} File\n.";
elif ((401<= $height &&  $height<=660))
then
    let COUNT480p++
    desired="500k";
    min="200k";
    max="1000k";
    echo -e "This is a ${UPurple}480p${Color_Off} File\n";
elif ((661<= $height &&  $height<=890))
then
    let COUNT720p++
    desired="800k";
    min="250k";
    max="1300k";
    echo -e "This is a ${UPurple}720p${Color_Off} File\n";
elif ((891<= $height &&  $height<=1200))
then
    let COUNT1080p++
    desired="1200k";
    min="350k";
    max="2300k";
    echo -e "This is a ${UPurple}1080p${Color_Off} File\n";
elif ((1201<= $height &&  $height<=2200))
then
    let COUNT2160p++
    desired="1500k";
    min="550k";
    max="2700k";
    echo -e "This is a ${UPurple}2160p${Color_Off} File\n";
elif ((2201<= $height &&  $height<=4400))
then
    let COUNT8K++
    desired="2000k";
    min="750k";
    max="3000k";
    echo -e "This is a ${UPurple}8K${Color_Off} File\n";
else
    let COUNTNA++
    echo -e "This is an ${URed}UNKNOWN${Color_Off} File\n";
fi
    echo -e "This is the input file $i\n";
	codec=${codec// /}

if [[ "$codec" = "hevc" ]]
then
	let COUNTERConverted++
    echo -e "${UGreen}################# h265 FILE!!!#####################${Color_Off}"
	filename="${filename/HEVC/h265}"
	filename="${filename/x264/h265}"
	filename="${filename/h264/h265}"
	filename="${filename/AVC/h265}"
	filename="${filename/VC-1/h265}"
	filename="${filename/MPEG2/h265}"
	filename="${filename/MPEG/h265}"
	filename="${filename/XviD/h265}"
	filename="${filename/DivX/h265}"
	filename="${filename/Div3/h265}"
	filename="${filename/VP6/h265}"
	filename="${filename/VP7/h265}"
	filename="${filename/VP8/h265}"
	filename="${filename/VP9/h265}"
	filename="${filename/WMV/h265}"
	filename="${filename/WMV1/h265}"
	filename="${filename/WMV2/h265}"
	filename="${filename/MP42/h265}"
	filename="${filename/MP43/h265}"
	echo -e "mv $i $d/$filename.$extension\n";
        echo -e "$i --> $codec">>$logConverted
	####mv $i $d/$filename.$extension
	echo -e "This is the outputfile $d/$filename.$extension\n";
else
	echo -e "${URed}$codec which is NOT A h265 file. Needs conversion!!${Color_Off}"
        echo -e "$i --> $codec">>$logToConvert
	let COUNTERtoConvert++
fi

echo -e "\n`pwd`"
echo -e "\n`date`"
echo -e "${UYellow}Total files scanned: $COUNTER"
echo -e "Total files converted to hevc/h265: $COUNTERConverted"
echo -e "Total files to be converted to hevc/h265: $COUNTERtoConvert"
echo -e "Total LOW Quality files scanned: $COUNTLow"
echo -e "Total 480p Quality files scanned: $COUNT480p"
echo -e "Total 720p Quality files scanned: $COUNT720p"
echo -e "Total 1080p Quality files scanned: $COUNT1080p"
echo -e "Total 2160/4K Quality files scanned: $COUNT2160p"
echo -e "Total 8K Quality files scanned: $COUNT8K"
echo -e "Total NA Quality files scanned: $COUNTNA${Color_Off}"
done
