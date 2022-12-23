#!/bin/bash
# MAGi SynthaVision Demo (Elmsford NY 1974) (Joanne Mitchell, Bob Goldstein, Bo Gehring, et al.) [4K AI upscale]
# See it as you've never seen it before!
# Generation script by Fredrick R. Brennan <copypaste@kittens.ph>.
# Public domain.

for p in ffmpeg wget parallel realesrgan-ncnn-vulkan; do
    hash $p || (>&2 echo "install $p"'!' && exit 1)
done

for t in vtt srt; do
    [ ! -f synthavision.$t ] && \
        ffmpeg -i synthavision.ass synthavision.$t
done
[ ! -f synthavision.mp4 ] && \
    wget https://archive.org/download/synthavisionsampler/synthavisionsampler.mp4
[ ! -f synthavision.mkv ] && \
    ffmpeg -i synthavision.mp4 -c:v hevc_nvenc -filter_complex 'tmedian,spp=5:10:1:0' \
    -qp 0 -c:a aac synthavision.mkv
[ ! -d pngs ] && (
    mkdir pngs
    ffmpeg -i synthavision.mkv -vsync 0 ./pngs/%05d.png
)
[ ! -d outpngs ] && (
    mkdir outpngs
    realesrgan-ncnn-vulkan -i pngs -g 2 -n realesrgan-x4plus -o outpngs
)
[ ! -d svgifpngs ] && (
    mkdir svgifpngs
    seq -w 670 1040 | parallel cp 'outpngs/0{}.png' 'svgifpngs'
    ls svgifpngs | parallel --bar --plus mv 'svgifpngs/{}' 'svgifpngs/00{0#}.png'
)
[ ! -f synthavision.gif ] && \
    ffmpeg -framerate 24 -i svgifpngs/%05d.png -filter_complex \
        "[0:v] scale=600:-1,fps=15[s];
         [s]split[s1][s2];
         [s1]palettegen=stats_mode=single:max_colors=144[p];
         [s2][p]paletteuse=new=1" \
        -framerate 15 synthavision.gif

[ ! -d brillopngs ] && (
    mkdir brillopngs
    seq -w 1613 2264 | parallel cp 'outpngs/0{}.png' 'brillopngs/temp{}.png'
    ls brillopngs | parallel --bar --plus mv 'brillopngs/{}' 'brillopngs/00{0#}.png'
)
for f in brillo.mkv out.mkv; do
    [ ! -f "$f" ] && \
        ffmpeg -framerate 24 -r 24 -i "${f%%.mkv}pngs"/%05d.png \
            $( [ "$f" = "out.mkv" ] && \
                   printf -- "%s" "-i synthavision.mkv -i" \
                                  " synthavision.ass" || true ) \
             -c:v h264_nvenc -c:a aac -qp 20 -r 30 "${f%%.mkv}.mkv"
    [ ! -f "${f%%.mkv}.mp4" ] && \
        ffmpeg -i "$f" -c:v copy -c:a copy -c:s mov_text "${f%%.mkv}.mp4"
done
