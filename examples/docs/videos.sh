#!/bin/bash

#ffmpeg -framerate 5 -i ../video/Development%03d.jpeg -c:v libx264 -pix_fmt yuv420p Development.gif
# ffmpeg -framerate 5 -i ../video/Development%03d.jpeg \
#     -vf "scale=600:-2:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128:reserve_transparent=0[p];[s1][p]paletteuse" \
#     ../../docs/src/assets/Development.gif

# ffmpeg -framerate 20 -i ../video/Coalescence%03d.jpeg \
#     -vf "scale=600:-2:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128:reserve_transparent=0[p];[s1][p]paletteuse" \
#      ../../docs/src/assets/Coalescence.gif

# ffmpeg -framerate 10 -i ../video/Bacteries%03d.jpeg \
#     -vf "scale=600:-2:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128:reserve_transparent=0[p];[s1][p]paletteuse" \
#     ../../docs/src/assets/Bacteries.gif

ffmpeg -framerate 10 -i ../video/Patterning%03d.jpeg \
    -vf "scale=600:-2:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128:reserve_transparent=0[p];[s1][p]paletteuse" \
    ../../docs/src/assets/Patterning.gif
