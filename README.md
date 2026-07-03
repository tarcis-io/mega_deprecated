# Mega
The hallucinator machine.


sudo apt-get install build-essential libnspr4 libnss3 -y

install rust
rustup target add wasm32-unknown-unknown

cargo install trunk --locked
cargo install cargo-leptos --locked

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
