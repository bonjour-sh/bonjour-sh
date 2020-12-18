#!/usr/bin/python3

import os
import pathlib
from includes.Questions import Questions

enquete = Questions()
#enquete.ask("accept", "Welcome. Use this at your own risk. Continue?", True);
print(enquete.questions)

# Get the paths
pwd = pathlib.Path(__file__).parent.absolute()
print(type(pwd))
#pwd_apps = os.path.join(os.fsdecode(pwd), '/applications')
#print(pwd_apps)
"""
# Loop through the mandatory application files, collect an array
for file in os.listdir(os.path.join(pwdapps, '/mandatory')):
    filename = os.fsdecode(file)
    if not filename.endswith('.py'):
        continue
    print(os.path.join(pwdapps, filename))
"""