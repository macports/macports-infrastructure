#!/usr/bin/env python

from __future__ import print_function

import sys
import os
import pprint as pp
from maxcdn import MaxCDN

if not all(k in os.environ for k in ["MAXCDN_KEY", "MAXCDN_SECRET"]):
    print("Error: MAXCDN_KEY or MAXCDN_SECRET not set in environment!", file=sys.stderr)
    sys.exit(1)

if len(sys.argv) != 2:
    print("Usage: {} <zoneid>".format(sys.argv[0]), file=sys.stderr)
    sys.exit(1)

zoneid = sys.argv[1]
MAXCDN_ALIAS = "macports"
MAXCDN_KEY = os.environ["MAXCDN_KEY"]
MAXCDN_SECRET = os.environ["MAXCDN_SECRET"]

# Initialize MaxCDN API
maxcdn = MaxCDN(MAXCDN_ALIAS, MAXCDN_KEY, MAXCDN_SECRET)

# Purge requested zone
res = maxcdn.purge(zoneid)
if not 'code' in res:
    print("Error: Unexpected response:", file=sys.stderr)
    pp.pprint(res, file=sys.stderr)
    sys.exit(1)
elif res['code'] == 200:
    print("Zone {} purged.".format(zoneid))
else:
    print("Purging of zone {} failed with code: " + res['code'], file=sys.stderr)
    sys.exit(1)
