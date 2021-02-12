import os, pathlib, subprocess

class Config:

    path = '';
    handle = '';
    separator = ''; # keys and values are separated by

    def __init__(self, path):
        self.open(os.getcwd() + path)

    def open(self, path):
        self.path = path;

    def usesSpaceSeparator(self):
        self.separator = ' ';

    def usesEqualsSeparator():
        self.separator = '=';

    def set(self, key, value):
        print('Setting '+key+' to '+value)
        subprocess.call(["sed -i 's/^ *# *"+key+" *[^ ]*/"+key+self.separator+value+"' "+self.path+"'"], shell=True)
