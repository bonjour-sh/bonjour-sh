#!/usr/bin/python3

import importlib
import os
import pathlib

from includes.Questions import Questions

enquete = Questions()

# Get the paths
pwd = pathlib.Path(__file__).parent.absolute()
pwd_apps = pathlib.Path.joinpath(pwd, 'applications')
pwd_apps_mandatory = pathlib.Path.joinpath(pwd_apps, 'mandatory')

# Files to use
files = []

# Loop through the mandatory application files, collect an array
for file in os.listdir(pwd_apps_mandatory):
    filename = os.fsdecode(file)
    if not filename.endswith('.py'):
        continue
    filename = pathlib.Path.joinpath(pwd_apps_mandatory, filename)
    # Skip empty files
    if os.stat(filename).st_size < 10:
        continue
    files.append(filename)

for file in files:
    application = getattr(importlib.import_module('applications.mandatory.Setup'), file.stem)(enquete)
    application.install()
    # print(instance)
    # instance.sayHi()
    # instance = Setup()

# print(enquete.questions)
