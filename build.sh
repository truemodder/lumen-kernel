#!/bin/bash

kernel_dir="${PWD}"
CCACHE=$(command -v ccache)
objdir="${kernel_dir}/out"
anykernel=$HOME/anykernel
builddir="${kernel_dir}/build"
ZIMAGE=$kernel_dir/out/arch/arm64/boot/Image
kernel_name="LumenKernel"
zip_name="$kernel_name-$(date +"%d%m%Y-%H%M").zip"
TC_DIR="${PWD}/tc"
export CONFIG_FILE="vendor/lahaina-qgki_defconfig"
export ARCH="arm64"
export KBUILD_BUILD_HOST=LumenKernel
export KBUILD_BUILD_USER=$(whoami)

export PATH="$TC_DIR/bin:$PATH"
if ! [ -d "$TC_DIR" ]; then
	echo "AOSP clang not found! Cloning to $TC_DIR..."
	if ! git clone --depth=1 -b 18 https://gitlab.com/ThankYouMario/android_prebuilts_clang-standalone "$TC_DIR"; then
		echo "Cloning failed! Aborting..."
		exit 1
	fi
fi

# Colors
NC='\033[0m'
RED='\033[0;31m'
LRD='\033[1;31m'
LGR='\033[1;32m'

echo -e "${LGR}######### Versão do Clang #########${NC}"
$TC_DIR/bin/clang --version

make_defconfig() {
    START=$(date +"%s")
    echo -e ${LGR} "########### Generating Defconfig ############${NC}"
    make -s ARCH=${ARCH} O=${objdir} CC=clang HOSTCC=clang ${CONFIG_FILE} LLVM=1 LLVM_IAS=1 -j$(nproc --all)
}

compile() {
    cd ${kernel_dir}
    echo -e ${LGR} "######### Compiling kernel #########${NC}"
    make -j$(nproc --all) \
    O=out \
    ARCH=${ARCH} \
    CC="ccache clang" \
    CLANG_TRIPLE="aarch64-linux-gnu-" \
    CROSS_COMPILE="aarch64-linux-gnu-" \
    CROSS_COMPILE_ARM32="arm-linux-gnueabi-" \
    LLVM=1 \
    LLVM_IAS=1
}

completion() {
    cd ${objdir}
    COMPILED_IMAGE=arch/arm64/boot/Image
    DTB_DIR=arch/arm64/boot/dts/vendor/qcom/
    COMPILED_DTBO=arch/arm64/boot/dts/vendor/qcom/*.img
    COMPILED_DTB=arch/arm64/boot/dts/vendor/qcom/lahaina*dtb
    if [[ -f ${COMPILED_IMAGE} ]]; then

        git clone -q https://github.com/raghavt20/AnyKernel3 -b tundra $anykernel

        cp -f ${COMPILED_IMAGE} $anykernel
        cp -f "${DTB_DIR}"/*.img $anykernel
        mkdir -p $anykernel/dtb
        cat "${DTB_DIR}"/lahaina-moto-base-v2.1.dtb "${DTB_DIR}"/lahaina-moto-base.dtb > $anykernel/dtb || abort "Failed to concatenate lahaina*.dtb to AnyKernel3 directory!"
        cd $anykernel
        find . -name "*.zip" -type f -delete
        zip -r AnyKernel.zip *
        cp AnyKernel.zip $zip_name
        cp $anykernel/$zip_name $kernel_dir/$zip_name
        rm -rf $anykernel
        END=$(date +"%s")
        DIFF=$(($END - $START))
        curl -F "file=@$kernel_dir/$zip_name" https://temp.sh/upload
        echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
        echo -e ${LGR} "#############################################"
        echo -e ${LGR} "####### Kernel compiled successfully ########"
        echo -e ${LGR} "#############################################${NC}"
    else
        echo -e ${RED} "#############################################"
        echo -e ${RED} "######## Failed to compile Kernel #########"
        echo -e ${RED} "#############################################${NC}"
    fi
}

make_defconfig
compile
completion
cd ${kernel_dir}
