#!/bin/bash
# 
# Copyright 2021. Uecker Lab, University Medical Center Goettingen.
#
# Author: Xiaoqing Wang, 2020-2021
# xiaoqing.wang@med.uni-goettingen.de
#

set -e

usage="Usage: $0 <reco_imgs> <TI> <T1map> <imgs_masked> <coeff_maps_masked>"

if [ $# -lt 5 ] ; then

        echo "$usage" >&2
        exit 1
fi


reco_imgs=$(readlink -f "$1")
TI=$(readlink -f "$2")
T1_map=$(readlink -f "$3")
imgs_masked=$(readlink -f "$4")
coeff_maps_masked=$(readlink -f "$5")


if [ ! -e ${reco_imgs}.cfl ] ; then
        echo "Input reco_imgs file does not exist." >&2
        echo "$usage" >&2
        exit 1
fi

if [ ! -e ${TI}.cfl ] ; then
        echo "Input TI file does not exist." >&2
        echo "$usage" >&2
        exit 1
fi


if [ ! -e $TOOLBOX_PATH/bart ] ; then
       echo "\$TOOLBOX_PATH is not set correctly!" >&2
       exit 1
fi

# perform pixel-wise fitting to obtain (Mss, M0 R1*) map
python3 ../utils/mapping_pixelwise.py $reco_imgs T1 $TI tmp_fit_maps

# perform T1 calculation
bart extract 2 0 3 tmp_fit_maps tmp_reco_maps1
bart transpose 2 6 tmp_reco_maps1 tmp_reco_maps2
bart looklocker -t0.0 -D15.3e-3 tmp_reco_maps2 tmp_T1map
bart scale 0.5 tmp_T1map tmp_T1map1

# masking the results

# coefficient maps
bart fmac ../T1/T1-mask reco_coeff_maps tmp_reco_coeff_maps1
bart transpose 0 1 tmp_reco_coeff_maps1 tmp_reco_coeff_maps2
bart flip $(bart bitmask 1) tmp_reco_coeff_maps2 tmp_reco_coeff_maps

# images
bart fmac ../T1/T1-mask $reco_imgs tmp_reco_imgs1
bart transpose 0 1 tmp_reco_imgs1 tmp_reco_imgs2
bart flip $(bart bitmask 1) tmp_reco_imgs2 $imgs_masked

# T1 map
bart fmac ../T1/T1-mask tmp_T1map1 tmp_T1map2
bart transpose 0 1 tmp_T1map2 tmp_T1map3
bart flip $(bart bitmask 1) tmp_T1map3 $T1_map

# join the cofficient maps together (Figure 7A)
bart slice 6 0 tmp_reco_coeff_maps coeff1.coo
bart slice 6 1 tmp_reco_coeff_maps coeff0.coo
bart slice 6 2 tmp_reco_coeff_maps coeff2.coo
bart slice 6 3 tmp_reco_coeff_maps coeff3.coo

bart join 0 coeff*.coo $coeff_maps_masked

rm coeff*.coo


