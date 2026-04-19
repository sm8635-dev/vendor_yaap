#!/bin/bash
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
NC="\033[0m"

FORCE_JSON=1
NON_OFFICIAL_TAG="HOMEMADE"

findPayloadOffset() {
    build=$1
    info=$(zipdetails "$build")
    foundBin=0
    while IFS= read -r line; do
        if [[ $foundBin == 1 ]]; then
            echo "$line" | grep -q "PAYLOAD"
            res=$?
            if [[ $res == 0 ]]; then
                hexNum=$(echo "$line" | cut -d ' ' -f1)
                echo $(( 16#$hexNum ))
                break
            fi
            continue
        fi
        echo "$line" | grep -q "payload.bin"
        res=$?
        [[ $res == 0 ]] && foundBin=1
    done <<< "$info"
}

if ! [ "$1" ]; then
    echo -e "${RED}No file provided${NC}"
    if ! return 0 &> /dev/null; then
        exit 0
    fi
fi

file_path=$1
file_dir=$(dirname "$file_path")
file_name=$(basename "$file_path")
device_code=$(echo "${file_name}" | cut -d'-' -f4)

if ! [ -f "$file_path" ]; then
    echo -e "${RED}File does not exist${NC}"
    if ! return 0 &> /dev/null; then
        exit 0
    fi
fi

isOfficial=1
if [[ $FORCE_JSON == 1 ]]; then
    echo -e "${GREEN}Forced generation of json${NC}"
else
    if [[ $file_name == *"${NON_OFFICIAL_TAG}"* ]]; then
        isOfficial=0
    fi
fi

if [[ $isOfficial != 1 ]]; then
    echo -e "${YELLOW}Skipped generating json for a non-official build${NC}"
    if ! return 0 &> /dev/null; then
        exit 0
    fi
fi

echo -e "${GREEN}Generating ${YELLOW}${device_code}.json${NC}"

isPayload=0
[ -f payload_properties.txt ] && rm payload_properties.txt
if unzip "$file_path" payload_properties.txt; then
    isPayload=1
    offset=$(findPayloadOffset "$file_path")
    keyPairs=$(cat payload_properties.txt | sed "s/=/\": \"/" | sed 's/^/          \"/' | sed 's/$/\"\,/')
    keyPairs=${keyPairs%?}
fi
# get date from props
datetime=$(grep "ro.build.date.utc" "${file_dir}/system/build.prop" | cut -d '=' -f 2)

{
    echo    "{"
    echo    "  \"response\": ["
    echo    "    {"
    echo    "      \"datetime\": ${datetime},"
    echo -n "      \"filename\": \"${file_name}\""
} > "${file_path}.json"
if [[ $isPayload == 1 ]]; then
    {
        echo ","
        echo "      \"payload\": ["
        echo "        {"
        echo "          \"offset\": ${offset},"
        echo "${keyPairs}"
        echo "        }"
        echo "      ]"
    } >> "${file_path}.json"
else
        echo "" >> "${file_path}.json"
fi
{
        echo "    }"
        echo "  ]"
        echo "}"
} >> "${file_path}.json"

mv "${file_path}.json" "${file_dir}/${device_code}.json"
echo -e "${GREEN}Done generating ${YELLOW}${file_dir}/${device_code}.json${NC}"
