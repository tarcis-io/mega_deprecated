# Mega
The hallucinator machine.

---

sudo apt-get install build-essential libnspr4 libnss3 -y

---

wget https://go.dev/dl/go1.26.4.linux-amd64.tar.gz

tar -xvf go1.26.4.linux-amd64.tar.gz

rm -rf go1.26...

mkdir .go

.bashrc:

export GOROOT=$HOME/go

export GOPATH=$HOME/.go

export PATH=$PATH:$GOROOT/bin

---

tinygo

---

wget https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/2.1.1-6123990880747520/linux-x64/Antigravity%20IDE.tar.gz

tar -xvf An...

mv An antigravity-ide

chmod +x antigravity-ide/antigravity-ide

chmod +x antigravity-ide/bin/an

chmod +x chrome_crashpad_handler

chmod +x resources/app/extensions/git/dist/askpass.sh

chmod +x resources/app/node_modules/@vscode/ripgrep/bin/rg

mkdir -p ~/.local/share/applications

vi ~/.loca/share/applications/antigravity-ide.desktop

[Desktop Entry]

Type=Application

Name=Antigravity IDE

Comment=Google Antigravity Integrated Development Environment

Exec=/home/mega/antigravity-ide/antigravity-ide

Icon=/home/mega/antigravity-ide/resources/app/resources/linux/code.png

Terminal=false

Categories=Development;IDE;

---
