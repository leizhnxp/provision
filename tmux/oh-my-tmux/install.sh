#!/bin/bash

# ref https://github.com/gpakosz/.tmux/blob/master/README.md

cd
git clone https://github.com/gpakosz/.tmux.git
ln -s -f .tmux/.tmux.conf
cp .tmux/.tmux.conf.local .

tmux source-file ~/.tmux.conf
