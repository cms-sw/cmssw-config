#!/usr/bin/env python
import os, sys, re, gzip
from os import environ
from argparse import ArgumentParser
from subprocess import  check_output

sys.path.append(environ["SCRAM_TOOL_HOME"])
from SCRAM.Core.Utils import readProducts
from SCRAM.BuildSystem.ToolManager import ToolManager
from SCRAM.Configuration.ConfigArea import ConfigArea


help_text = "%s <localtop> <USES|USED_BY|ORIGIN> <tool|package> [<arch>]" % sys.argv[0]
parser = ArgumentParser(usage=help_text)
parser.add_argument('localtop')
parser.add_argument('cmd', choices=["USES", "USED_BY", "ORIGIN"])
parser.add_argument('pack')
parser.add_argument('arch', default = os.environ.get("SCRAM_ARCH"))
args = parser.parse_args()
localtop = args.localtop
cmd = args.cmd.upper()
pack = args.pack
arch = args.arch
os.environ["SCRAM_ARCH"] = arch
cache = {}
tools = {}
data = dict(DATA = {}, FILES = {}, PROD = {}, DEPS = {})


def scramVersion(dir):
  ver = ""
  path = os.path.join(dir, "config", "scram_version")
  if os.path.exists(path):
    with open(path) as file:
      ver = file.readline()
  return ver


def FixToolName(t):
  lct = t.lower()
  if lct in tools: 
    return lct
  return t


def process_ORIGIN(data, prod):
  str = "%s_ORIGIN = " % prod
  if prod not in data["PROD"]: data["PROD"][prod] = {}
  if "ORIGIN" in data["PROD"][prod]:
    for dir in data["PROD"][prod]["ORIGIN"]:
      tool = data["PROD"][prod]["ORIGIN"][dir]
      str += os.path.join(tool, "%s " % dir)
  print(str)


def process_USED_BY(data, pack):
  packs = []
  str = "%s_USED_BY = " % pack
  if "USED_BY" in data[pack]:
    for d in data[pack]["USED_BY"]:
      packs.append(os.path.join(data[d]["TYPE"],d))
    str += " ".join(sorted(packs))
  print(str)


def process_USES(data, pack):
  packs = []
  str = "%s_USES = " % pack
  if "USES" in data[pack]:
    for d in data[pack]["USES"]:
      if "TYPE" not in data[d]:
        data[d]["TYPE"] = "tool"
      packs.append(os.path.join(data[d]["TYPE"],d))
    str += " ".join(sorted(packs))
  print(str)


def updateSCRAMTool(tool, base, data):
  area = ConfigArea()
  area.location(base)
  c = readProducts(area)
  for dir in c:
    dc = c[dir]
    _class = dc["CLASS"]
    prod = None
    if _class in ["LIBRARY"]:
      prod = dc["NAME"]
    if dir not in data["DATA"]: data["DATA"][dir] = {"USES":{}, "TYPE": tool}
    if "USE" in dc:
      for d in dc["USE"]:
        data["DATA"][dir]["USES"][FixToolName(d)] = 1
    if prod: 
      if prod not in data["PROD"]: data["PROD"][prod] = {"ORIGIN":{dir:tool}}
    elif "BUILDPRODUCTS" in dc:
      dc = dc["BUILDPRODUCTS"]
      for type in ("LIBRARY", "BIN"):
        if type in dc:
          for prod in dc[type]:
            if "USE" in dc[type][prod]:
              for d in dc[type][prod]["USE"]:
                data["DATA"][dir]["USES"][FixToolName(d)] = 1
            if prod not in data["PROD"]: data["PROD"][prod] = {"ORIGIN":{dir:tool}}


def updateDeps(data, pack=None):
  if not pack:
    for d in data["DATA"]: updateDeps(data, d)
    return 0
  if pack in data: return 0
  if pack not in data: data[pack] = { "USES": {}, "USED_BY": {}, "TYPE": data["DATA"][pack]["TYPE"] }
  for u in data["DATA"][pack]["USES"]:
    if u in data["DATA"]: updateDeps(data, u)
    data[pack]["USES"][u] = 1
    if u not in data: data[u] = {}
    if "USED_BY" not in data[u]: data[u]["USED_BY"] = {pack : 1}
    if "USES" not in data[u]: data[u]["USES"] = {}
    for d in data[u]["USES"]:
      data[pack]["USES"][d] = 1
      data[d]["USED_BY"][pack] = 1


def updateExternals():
  area = ConfigArea()
  area.location(localtop)
  toolmgr = ToolManager(area)
  tools = toolmgr.loadtools()
  for t in sorted(tools.keys()):
    file = os.path.join(localtop, ".SCRAM", arch, "tools", t)
    if not os.path.exists(file): print("No such file: %s" % file) & sys.exit(1)
    data["FILES"][file] = 1
    if t not in data["DATA"]: data["DATA"][t] = {"USES":{}, "TYPE": "tool"}
    tc = tools[t]
    if "USE" in tc:
      for d in tc["USE"]:
        data["DATA"][t]["USES"][FixToolName(d)] = 1
    if "LIB" in tc:
      for l in tc["LIB"]:
        if l not in data["PROD"]: data["PROD"][l] = {"ORIGIN": {t: "tool"}}
  order_path = os.path.join(localtop, ".SCRAM", arch, "MakeData", "Tools", "SCRAMBased", "order")
  if os.path.exists(order_path):
    for t in check_output('sort -r %s' % order_path, shell=True).decode().rstrip().splitlines():
      t = re.sub(r'^\d+:', r'', t)
      base = ""
      if t == "self": 
        base = reltop
      else: 
        base = "%s_BASE" % t.upper()
        base = tools[t][base]
      updateSCRAMTool(t, base, data)
  updateSCRAMTool("self", localtop, data)
  updateDeps(data)
  del data["DATA"]
  tools = None
  return data


envfile = os.path.join(localtop, ".SCRAM", arch, "Environment")
if not os.path.exists(envfile): envfile = os.path.join(localtop, ".SCRAM", "Environment")
reltop = check_output("grep RELEASETOP= %s | sed 's|RELEASETOP=||'" % envfile, shell=True).decode().rstrip()
cacheext="db"
if re.search(r'^V[2-9]' ,scramVersion(localtop)): cacheext="db.gz"
cache = updateExternals()
func = globals()["process_" + cmd]
for pk in pack.split(":"): func(cache, pk)
