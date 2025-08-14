#!/bin/bash
START_TIME=$(date +%s)
if [ "$1" == "cleanup" ]; then
    echo "Cleaning up work dirs..."
    rm -rf _AP _CSC _images _update_bin
    echo "Done"
elif [ "$1" == "cleanupall" ]; then
    echo "Cleaning up everything..."
    rm -rf _AP _CSC _images _update_bin _odin_extracted out Progress.txt
    echo "Done"
fi
set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 [path to base firmware ZIP] [path to update bin ZIP]"
    exit 1
fi

BASE_ZIP="$1"
UPDATE_ZIP="$2"
echo
echo "===== Samsung Beta Firmware Merger ====="
echo "= Coded by @EndaDwagon at t.me/endarom ="
echo "Base firmware: $BASE_ZIP"
echo "Update binary: $UPDATE_ZIP"
echo

# Check dependencies
for cmd in unzip tar lz4; do
    if ! command -v $cmd >/dev/null 2>&1; then
        echo "$cmd is not installed. Installing..."
        sudo apt update && sudo apt install -y $cmd
    fi
done

# Extract base firmware zip
echo
echo "Extracting ODIN firmware ZIP..."
mkdir -p _odin_extracted
unzip -q "$BASE_ZIP" -d _odin_extracted

# Find AP tar inside base ZIP
echo
AP_TAR=$(find _odin_extracted -type f -name "AP*.tar.md5" | head -n 1)
if [ -z "$AP_TAR" ]; then
    echo "Error: Could not find AP*.tar.md5 in base ZIP!"
    exit 1
fi
echo
BL_TAR=$(find _odin_extracted -type f -name "BL*.tar.md5" | head -n 1)
if [ -z "$BL_TAR" ]; then
    echo "Error: Could not find BL*.tar.md5 in base ZIP!"
fi
echo
CP_TAR=$(find _odin_extracted -type f -name "CP*.tar.md5" | head -n 1)
if [ -z "$CP_TAR" ]; then
    echo "Error: Could not find CP*.tar.md5 in base ZIP!"
fi
echo
CSC_TAR=$(find _odin_extracted -type f -name "CSC*.tar.md5" | head -n 1)
if [ -z "$CSC_TAR" ]; then
    echo "Error: Could not find CSC*.tar.md5 in base ZIP!"
    exit 1
fi
HOME_TAR=$(find _odin_extracted -type f -name "HOME_CSC*.tar.md5" | head -n 1)
if [ -z "$HOME_TAR" ]; then
    echo "Error: Could not find HOME_CSC*.tar.md5 in base ZIP!"
    exit 1
fi
echo "Found AP package: $AP_TAR"
echo "Found BL package: $BL_TAR"
echo "Found CP package: $CP_TAR"
echo "Found CSC package: $CSC_TAR"
echo "Found HOME_CSC package: $HOME_TAR"

# Extract optics and prism from csc
echo
echo "Extracting optics.img.lz4 and prism.img.lz4 from CSC..."
mkdir -p _lz4tmp
tar -xf "$CSC_TAR" --no-same-owner -C _lz4tmp optics.img.lz4 prism.img.lz4

# Extract super.img.lz4 from AP
echo
echo "Extracting super.img.lz4 from AP..."
tar -xf "$AP_TAR" --wildcards --no-same-owner -C _lz4tmp 'super.img.lz4'

if [ ! -f _lz4tmp/super.img.lz4 ]; then
    echo "Error: super.img.lz4 not found in AP package!"
    exit 1
fi

# De-LZ4
echo
echo "Decompressing lz4 images..."
mkdir _images
lz4 -d _lz4tmp/optics.img.lz4 _images/optics.img
lz4 -d _lz4tmp/prism.img.lz4 _images/prism.img
lz4 -d _lz4tmp/super.img.lz4 _images/super.img
rm -rf _lz4tmp

# Desparse super
echo
echo "Desparsing super..."
./imjtool _images/super.img extract
mv _images/super.img _images/super.img-old 2>/dev/null
mv extracted/image.img _images/super.img
rm -rf extracted

# Extract super
echo
echo "Extracting super"
mkdir _images/super
mkdir _images/super/images
./lpdump _images/super.img > _images/super/superlpdump.txt
./lpunpack _images/super.img _images/super/images
echo "Super Extracted"

# Parse super
parse_super_partitions() {
    local lpdump_file="$1"
    local partitions=()
    
    echo "Parsing super layout..."
    
    while IFS= read -r line; do
        if [[ $line == *"Name:"* ]]; then
            partition_name=$(echo "$line" | sed 's/.*Name: \([^[:space:]]*\).*/\1/')
            partitions+=("$partition_name")
        fi
    done < "$lpdump_file"
    
    echo "Found partitions in super: ${partitions[*]}"
    echo "${partitions[@]}"
}

extract_super_properties() {
    local lpdump_file="$1"
    
    echo
    echo "Extracting super properties..."
    
    # Parse the specific format from your lpdump output
    SUPER_SIZE=$(grep "Size:" "$lpdump_file" | grep "bytes" | awk '{print $(NF-1)}')
    METADATA_SIZE=$(grep "Metadata max size:" "$lpdump_file" | awk '{print $4}')
    METADATA_SLOTS=$(grep "Metadata slot count:" "$lpdump_file" | awk '{print $4}')
    
    echo "Super properties:"
    echo "  Size: $SUPER_SIZE bytes"
    echo "  Metadata size: $METADATA_SIZE bytes"
    echo "  Metadata slots: $METADATA_SLOTS"
}

SUPER_PARTITIONS=($(parse_super_partitions "./_images/super/superlpdump.txt"))
extract_super_properties "./_images/super/superlpdump.txt"

# Extract update bin
echo
echo "Extracting update bin..."
mkdir -p _update_bin
unzip -q "$UPDATE_ZIP" -d _update_bin
echo "Update BIN Extracted."

PARTITIONS=("system" "product" "odm" "vendor" "system_dlkm" "vendor_dlkm" "system_ext")
EXTRAPARTITIONS=("optics" "prism")

echo "Starting merge..."

for partition in "${PARTITIONS[@]}"; do
    img_file="./_images/super/images/${partition}.img"
    transfer_list="./_update_bin/${partition}.transfer.list"
    new_dat="./_update_bin/${partition}.new.dat"
    patch_dat="./_update_bin/${partition}.patch.dat"
    
    if [ -f "$img_file" ] && [ -f "$transfer_list" ] && [ -f "$new_dat" ] && [ -f "$patch_dat" ]; then
    	echo
        echo "Merging ${partition}..."
        ./BlockImageUpdate "$img_file" "$transfer_list" "$new_dat" "$patch_dat" > /dev/null 2>&1
        echo "${partition} merge complete!"
    else
    	echo
        echo "Skipping ${partition} (doesn't exist)"
    fi
done
for partition in "${EXTRAPARTITIONS[@]}"; do
    img_file="./_images/${partition}.img"
    transfer_list="./_update_bin/${partition}.transfer.list"
    new_dat="./_update_bin/${partition}.new.dat"
    patch_dat="./_update_bin/${partition}.patch.dat"
    
    if [ -f "$img_file" ] && [ -f "$transfer_list" ] && [ -f "$new_dat" ] && [ -f "$patch_dat" ]; then
    	echo
        echo "Merging ${partition}..."
        ./BlockImageUpdate "$img_file" "$transfer_list" "$new_dat" "$patch_dat" > /dev/null 2>&1
        echo "${partition} merge complete!"
    else
        echo "Skipping ${partition} (doesn't exist)"
    fi
done
rm -rf cache
rm -rf Progress.txt
echo
echo "Rebuilding super partition..."

mkdir _build_tmp

MERGED_IMAGES_DIR="./_images/super/images"

./lpmake \
    --metadata-size ${METADATA_SIZE:-65536} \
    --super-name super \
    --metadata-slots ${METADATA_SLOTS:-2} \
    --device super:${SUPER_SIZE} \
    --group main:$(du -cb ${MERGED_IMAGES_DIR}/*.img | tail -1 | cut -f1) \
    $(for img in ${MERGED_IMAGES_DIR}/*.img; do
        if [ -f "$img" ]; then
            partition=$(basename "$img" .img)
            size=$(stat -c%s "$img")
            echo "--partition ${partition}:readonly:${size}:main --image ${partition}=${img}"
        fi
    done) \
    --sparse \
    --output ./_build_tmp/super.img 2>&1 | grep -v "Invalid sparse file format"
    
echo "Super rebuilt"

echo
echo "Preparing to build Odin tars"

# Moving images around
cp _images/optics.img _images/super/images/optics.img
cp _images/prism.img _images/super/images/prism.img
mv _images/optics.img _build_tmp/optics.img
mv _images/prism.img _build_tmp/prism.img

cd _build_tmp
lz4 -B6 --content-size optics.img optics.img.lz4
rm -rf optics.img
lz4 -B6 --content-size prism.img prism.img.lz4
rm -rf prism.img
lz4 -B6 --content-size super.img super.img.lz4
rm -rf super.img
cd ../_update_bin
rm -rf system.transfer.list system.new.dat system.patch.dat product.transfer.list product.new.dat product.patch.dat odm.transfer.list odm.new.dat odm.patch.dat vendor.transfer.list vendor.new.dat vendor.patch.dat system_dlkm.img system_dlkm.transfer.list system_dlkm.new.dat system_dlkm.patch.dat vendor_dlkm.transfer.list vendor_dlkm.new.dat vendor_dlkm.patch.dat system_ext.transfer.list system_ext.new.dat system_ext.patch.dat optics.transfer.list optics.new.dat optics.patch.dat prism.transfer.list prism.new.dat prism.patch.dat META-INF
cd ..

# Replace files in current Odin tars
mkdir _AP
mkdir _CSC
tar -xf "$AP_TAR" -C _AP/
tar -xf "$CSC_TAR" -C _CSC/
rm -rf _AP/super.img.lz4
rm -rf _CSC/optics.img.lz4
rm -rf _CSC/prism.img.lz4
mv _build_tmp/super.img.lz4 _AP/super.img.lz4
mv _build_tmp/optics.img.lz4 _CSC/optics.img.lz4
mv _build_tmp/prism.img.lz4 _CSC/prism.img.lz4
rm -rf _build_tmp

# Compile tars and finish!
mkdir out
mkdir out/odin

# Rebuild tars
echo
echo "Rebuilding AP..."
AP_NAME=$(basename "$AP_TAR")
tar -cf "out/odin/$AP_NAME" -C _AP/ .
echo "AP tar rebuilt as: out/odin/$AP_NAME"
echo
echo "No changes made to BL, copying..."
cp "$BL_TAR" out/odin
echo
echo "Rebuilding CSC..."
CSC_NAME=$(basename "$CSC_TAR")
tar -cf "out/odin/$CSC_NAME" -C _CSC/ .
echo "CSC tar rebuilt as: out/odin/$CSC_NAME"
echo
echo "No changes made to CP, copying..."
cp "$CP_TAR" out/odin
echo
echo "No changes made to HOME_CSC, copying..."
cp "$HOME_TAR" out/odin
echo
echo "Odin tars completed"


# Move raw images to out
echo
echo "Moving raw images to out/images"
mv _images/super/images out/
echo "Done"
echo

# Nuke work dirs
echo "Cleaning up work dirs"
rm -rf _AP _CSC _images _update_bin
echo "Cleanup complete."

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
HOURS=$((ELAPSED / 3600))
MINS=$(((ELAPSED % 3600) / 60))
SECS=$((ELAPSED % 60))
echo
if [ $HOURS -gt 0 ]; then
    echo "Merge complete in ${HOURS}hr ${MINS}min ${SECS}sec"
elif [ $MINS -gt 0 ]; then
    echo "Merge complete in ${MINS}min ${SECS}sec"
else
    echo "Merge complete in ${SECS}sec, damn that was quick"
fi
