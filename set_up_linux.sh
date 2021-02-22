#!/usr/bin/env bash

app_list="curl wget git zsh vim screen zip unzip"

grep debian /etc/os-release && sudo apt install $app_list -y

grep centos /etc/os-release && sudo yum install $app_list -y

