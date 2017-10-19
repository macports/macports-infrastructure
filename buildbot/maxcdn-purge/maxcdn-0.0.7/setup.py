#!/usr/bin/env python
# -*- coding: utf-8 -*-

options = {
    "name":         "maxcdn",
    "version":      "0.0.7",
    "description":  "A Python REST Client for MaxCDN REST Web Services",
    "author":       "Joshua P. Mervine",
    "author_email": "joshua@mervine.net",
    "license":      "MIT",
    "keywords":     "MaxCDN CDN API REST",
    "packages":     ['maxcdn'],
    "url":          'http://github.com/maxcdn/python-maxcdn'
}

install_requires = [
    "requests",
    "requests_oauthlib",
    "certifi"
]
tests_require = [
    "nose",
    "mock"
]
include_package_data = True

try:
    from setuptools import setup
    options["install_requires"] = install_requires
    options["include_package_data"] = include_package_data
    options["tests_require"] = tests_require
    setup(**options)

except ImportError:
    print("ERROR: setuptools wasn't found, please install it")
