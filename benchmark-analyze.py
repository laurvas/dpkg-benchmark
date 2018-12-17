#!/usr/bin/env python3
import sys
import numpy as np

if len(sys.argv) != 2:
    print(sys.argv[0], "need one argument")
    exit(0)

time_data = dict()

with open(sys.argv[1]) as data_file:
    for line in data_file:
        real = float(line.split()[0])
        user = float(line.split()[1])
        sys = float(line.split()[2])
        variant = line.split()[-1]
        time_data.setdefault(variant, [[], [], []])
        time_data[variant][0].append(real)
        time_data[variant][1].append(user)
        time_data[variant][2].append(sys)

for variant in time_data:
    for i, time_list in enumerate(time_data[variant]):
        mean = np.mean(time_list)
        std = np.std(time_list, ddof=1)
        time_data[variant][i] = (mean, std)

reduced = dict()
for variant in time_data:
    booster = variant.split(',')[-1]
    mount_params = variant.split(',')[0:-1]
    mount_params = ','.join(mount_params)
    if not reduced.get(booster): reduced[booster] = dict()
    reduced[booster][mount_params] = time_data[variant]

sorted_normal = sorted(reduced['normal'].items(), key=lambda x: x[1][0][0])

normal_file = open('normal.dat', 'w')
unsafeio_file = open('unsafeio.dat', 'w')
eatmydata_file = open('eatmydata.dat', 'w')

for line in sorted_normal:
    mount_params = line[0]
    normal_data = [inner for outer in line[1] for inner in outer]
    unsafeio_data = [i for o in reduced['unsafeio'][mount_params] for i in o]
    eatmydata_data = [i for o in reduced['eatmydata'][mount_params] for i in o]
    print(mount_params, *normal_data, file=normal_file)
    print(mount_params, *unsafeio_data, file=unsafeio_file)
    print(mount_params, *eatmydata_data, file=eatmydata_file)
