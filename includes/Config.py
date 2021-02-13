import os
import re


class Config:
    path = ''
    handle = ''
    separator = ''  # keys and values are separated by

    def __init__(self, path):
        self.open(os.getcwd() + path)

    def open(self, path):
        self.path = path
        self.handle = open(path, 'r+')

    def usesSpaceSeparator(self):
        self.separator = ' '

    def usesEqualsSeparator(self):
        self.separator = '='

    def set(self, key, value):
        print('Setting ' + key + ' to ' + value)
        lines = self.handle.readlines()
        self.handle.seek(0)
        lines = map((lambda line: re.sub(r'^ *#* *' + key + '.*$', r'' + key + self.separator + value, line,
                                         flags=re.IGNORECASE)), lines)
        lines = list(lines)
        self.handle.write(''.join(lines))
        self.handle.truncate()
