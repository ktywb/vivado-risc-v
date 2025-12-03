#!/bin/bash

nohup ./job.sh > job.log.txt 2>&1 & echo $! > job.pid
