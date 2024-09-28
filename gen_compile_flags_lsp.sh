#!/bin/bash

pkg-config --cflags nvidia-ml | tr ' ' '\n' > compile_flags.txt
