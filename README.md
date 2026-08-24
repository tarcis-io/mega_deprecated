# Mega
The hallucinator machine.

---

sudo apt-get install build-essential libnspr4 libnss3 -y

---

wget https://go.dev/dl/go1.26.4.linux-amd64.tar.gz

tar -xvf go1.26.4.linux-amd64.tar.gz

rm -rf go1.26...

mkdir .go

---

mkdir bin

wget https://github.com/tailwindlabs/tailwindcss/releases/download/v4.3.3/tailwindcss-linux-arm64 -O bin/tailwindcss

chmod +x bin/tailwindcss

---

.bashrc:

export GOROOT=$HOME/go

export GOPATH=$HOME/.go

export PATH=$PATH:$HOME/bin:$GOROOT/bin

---

tinygo

---

wget "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64" -O vscode.deb

sudo apt install ./vscode.deb

rm -rf vscode.deb

---
