#!/bin/bash

set -e

echo "🔧 Cài dependencies..."
sudo apt update
sudo apt install -y \
  build-essential curl git unzip software-properties-common \
  libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev \
  libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev \
  ripgrep fd-find fzf xclip python3-pip

echo "📦 Cài Neovim ≥ 0.9..."
sudo add-apt-repository ppa:neovim-ppa/stable -y
sudo apt update
sudo apt install -y neovim

echo "📦 Cài Node.js (nvm)..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
export NVM_DIR="$HOME/.nvm"
source "$NVM_DIR/nvm.sh"
nvm install --lts
nvm use --lts

echo "🐍 Cài Python (pyenv)..."
curl https://pyenv.run | bash
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
pyenv install 3.13.0 -s
pyenv global 3.13.0

echo "📦 Cài pynvim bằng pip..."
pip install --upgrade pip
pip install pynvim

echo "📁 Clone LazyVim starter config..."
rm -rf ~/.config/nvim
git clone https://github.com/LazyVim/starter ~/.config/nvim
cd ~/.config/nvim
rm -rf .git

echo "✅ Cài xong! Chạy 'nvim' để khởi động LazyVim."
