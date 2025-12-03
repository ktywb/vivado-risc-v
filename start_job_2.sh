#!/bin/bash

nohup ./job2.sh > job2.log.txt 2>&1 & echo $! > job2.pid
