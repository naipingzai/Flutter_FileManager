mkdir -p build
cmake -S . -B build
cmake --build build -j$(nproc)
ls -lh build/
mkdir out
cp build/*.so out/
rm -rf build

