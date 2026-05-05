convert-icons:
    mkdir -p icons-in
    mkdir -p icons-out
    rm -f icons-out/*.png
    magick mogrify -path icons-out -trim +repage -gravity center -background none -extent "1:1#" -resize 64x64 -channel RGB -negate icons-in/*.png
    oxipng --strip all -z -o max -a -i off icons-out/*.png

optimize-icons:
    oxipng --strip all -z -o max -a -i off graphics/icons/*.png thumbnail.png