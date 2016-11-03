#!/usr/bin/env python

greatestAge = 0
greatestSize = 0
totalSize = 0

class archiveFile(object):
    """An archive file being considered for deletion"""
    def __init__(self, path, age, size):
        self.path = path
        self.age = age
        self.size = size

def weightedValue(age, size):
    """Combine an age and a size into a value out of 100"""
    weightedAge = (float(age) / float(greatestAge)) * 50.0
    weightedSize = (float(size) / float(greatestSize)) * 50.0
    return weightedAge + weightedSize

def weightedKey(archive):
    """Key extraction function for sorting using weightedValue"""
    return weightedValue(archive.age, archive.size)

import sys

versionFile = 'current_versions.txt'
rootDir = '.'

if len(sys.argv) > 1:
    rootDir = sys.argv[1]
    if len(sys.argv) > 2:
        versionFile = sys.argv[2]

import re
# patterns to match against for archives that are the current version
currentVersions = {}
fd = open(versionFile, 'r')
for line in fd:
    name, version = line.split()
    currentVersions[name] = re.compile(name+'-'+version+'[.+]')
fd.close()

import time
now = time.time()
fileList = []

import os
for portdir in os.listdir(rootDir):
    portDirPath = os.path.join(rootDir, portdir)
    if os.path.isdir(portDirPath):
        for archiveFilename in os.listdir(portDirPath):
            try:
                if archiveFilename.endswith('.rmd160') or currentVersions[portdir].match(archiveFilename):
                    continue
            except KeyError:
                pass
            archivePath = os.path.join(portDirPath, archiveFilename)
            if os.path.isfile(archivePath):
                thisAge = now - os.path.getmtime(archivePath)
                thisSize = os.path.getsize(archivePath)
                thisArchiveFile = archiveFile(archivePath, thisAge, thisSize)
                fileList.append(thisArchiveFile)
                if thisArchiveFile.age > greatestAge:
                    greatestAge = thisArchiveFile.age
                if thisArchiveFile.size > greatestSize:
                    greatestSize = thisArchiveFile.size
                totalSize += thisSize

fileList.sort(key=weightedKey, reverse=True)

for f in fileList:
    sys.stderr.write(f.path+' '+str(f.age)+' '+str(f.size)+': weighted value = '+str(weightedValue(f.age, f.size))+'\n')

# trim files until the total size of non-current archives remaining is this or less
targetSize = 200 * 10**9

for f in fileList:
    if totalSize <= targetSize:
        break
    print (f.path)
    sigpath = f.path+'.rmd160'
    if os.path.isfile(sigpath):
        print (sigpath)
    totalSize -= f.size
