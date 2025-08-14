# MergeAll - Merges Samsung OTA (Over The Air) binary files

### This script is currently still in development, some devices are not currently supported yet

### Currently MergeAll supports most Samsung devices older than the Galaxy S24 series

### MergeAll works best on devices from the Galaxy S20 series to the Galaxy S24 Series

## Deps

Firstly install the required deps

The most popular 3 package managers used here as an example, but it may vary throughout others

APT (Debian, Ubuntu, Linux mint)

```bash
sudo apt update && sudo apt install -y unzip tar lz4
```

DNF (Fedora, RHEL, CentOS Stream)

```bash
sudo dnf install unzip tar lz4
```

Pacman (Arch, Manjaro)

```bash
sudo pacman -Syu unzip tar lz4
```
## Usage guide
Firstly, clone my repo with git

```bash 
git clone https://github.com/EndaDwagon/MergeAll
```

Now CD to the clone

```bash
cd MergeAll
```

Now start merging with the command below!

```bash
./MergeAll.sh [path to ODIN firmware ZIP] [path to update BIN]
```

## Cleanup commands

```bash
./MergeAll.sh cleanup
```

Deletes everything in the MergeAll folder BUT extracted odin firmware and the out directory


```bash
./MergeAll.sh cleanupall
```

Deletes all work and out directories in the MergeAll folder
