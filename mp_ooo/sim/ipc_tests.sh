#!/bin/bash

# Arg Check
if [[ "$1" != "ve" && "$1" != "vcs" ]]; then
    echo "Usage: ./run_tests.sh [ve|vcs]"
    echo "  ve  - Use Verilator Simulation (make run_verilator_top_tb)"
    echo "  vcs - Use VCS Simulation (make run_vcs_top_tb)"
    exit 1
fi

if [[ "$1" == "ve" ]]; then
    make_command="make run_verilator_top_tb PROG="
elif [[ "$1" == "vcs" ]]; then
    make_command="make run_vcs_top_tb PROG="
fi

# Def Benchmarks
benchmarks=("Coremark" "Compression" "Mergesort" "FFT" "aes_sha")
elf_files=(
    "../testcode/coremark_im.elf"
    "../testcode/additional_testcases/compression.elf"
    "../testcode/cp3_release_benches/mergesort.elf"
    "../testcode/cp3_release_benches/fft.elf"
    "../testcode/cp3_release_benches/aes_sha.elf"
)

# Output file
result_file="ipc_results.md"

> "$result_file"

# Init test
ipc_values=()

for elf in "${elf_files[@]}"; do
    echo "Running Test: $elf"
    
    command="${make_command}${elf}"
    output=$($command 2>&1)
    
    ipc_line=$(echo "$output" | grep "Monitor: Segment IPC:" | awk '{print $4}')
    
    if [[ -n "$ipc_line" ]]; then
        echo "ELF: $elf - $ipc_line" >> "$result_file"
        echo "Monitor: Segment IPC: $ipc_line"
        ipc_values+=("$ipc_line")
    else
        ipc_values+=("N/A")
        echo "ELF: $elf - No IPC Found" >> "$result_file"
        echo "No IPC Found"
    fi
done

# Output to file

echo -e "\n" >> "$result_file"
echo "| Benchmark | Coremark | Compression | Mergesort | FFT | aes_sha |" >> "$result_file"
echo "| --- | --- | --- | --- | --- | --- |" >> "$result_file"

ipc_row="| Test |"
for ipc in "${ipc_values[@]}"; do
    ipc_row+=" $ipc |"
done

echo "$ipc_row" >> "$result_file"

# End
echo "All tests finished, check results in $result_file"
