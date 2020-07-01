#!/usr/bin/env python

import sys, re, os, json, gzip, shutil
from argparse import ArgumentParser
from os import path, environ
from subprocess import  call, check_output

base = sys.argv[0]
help_text = "\n\
    %s --project <name> --version <version> --scram <scram version>\n\
    --toolbox <toolbox> [--config <dir>] [--arch <arch>] [--help]\n\n\
    This script will copy all <name>_<files> files into <files>\n\
    and replace project names, version, scram verion, toolbox path\n\
    and extra keys/values provided via the command line. e.g.\n\n\
    %s -p CMSSW -v CMSSW_4_5_6 -s V1_2_0 -t /path/cmssw-tool-conf/CMS170\
 --keys MYSTRING1=MYVALUE1 --keys MYSTRING2=MYVALUE2\n\n\
    will release:\n\
    @PROJECT_NAME@=CMSSW\n\
    @PROJECT_VERSION@=CMSSW_4_5_6\n\
    @SCRAM_VERSION@=V1_2_0\n\
    @PROJECT_TOOL_CONF@=/path/cmssw-tool-conf/CMS170\n\
    @MYSTRING1@=MYVALUE1\n\
    @MYSTRING2@=MYVALUE2\n\n" % (base, base)
parser = ArgumentParser(usage=help_text)
parser.add_argument('--project', '-p', dest='project', required=True, help='Missing or empty project name.')
parser.add_argument('--version', '-v', dest='version', required=True, help='Missing or empty project version.')
parser.add_argument('--scram', '-s', dest='scram', required=True, help="Missing or empty scram version.")
parser.add_argument('--toolbox', '-t', dest='toolbox', required=True, help="Missing or empty SCRAM tool box path.")
parser.add_argument('--keys', dest='keys', action='append')
parser.add_argument('--arch', '-a', dest='arch', required=True)
args = parser.parse_args()
keys = dict(s.split('=') for s in args.keys)

tooldir = "tools"
if not path.isdir(path.join(args.toolbox, tooldir)):
    raise Exception("Wrong toolbox directory. Missing directory %s." % path.join(args.toolbox, tooldir))

dir = path.dirname(path.realpath(__file__))
environ["SCRAM_ARCH"] = args.arch
cache = {
    "KEYS" : {
                "PROJECT_NAME" : args.project,
                "PROJECT_VERSION": args.version,
                "PROJECT_TOOL_CONF": args.toolbox,
                "SCRAM_VERSION": args.scram,
                "PROJECT_CONFIG_BASE": path.dirname(dir),
                "SCRAM_COMPILER" : "gcc",
                "PROJECT_GIT_HASH" : {}
              },
    "SCRAMFILES" : {},
    "EXKEYS": {}
}
for f in ["bootsrc","BuildFile","Self","SCRAM_ExtraBuildRule","boot"]:
    cache["SCRAMFILES"][f] = 1

for k in keys:
    cache["KEYS"][k]=keys[k]
if not cache["KEYS"]["PROJECT_GIT_HASH"]: cache["KEYS"]["PROJECT_GIT_HASH"] = args.version

regexp = ""
for k in cache["KEYS"].keys():
    v  = cache["KEYS"][k]
    regexp += "s|\@%s\@|%s|g;" % (k,v)
for k in cache["EXKEYS"].keys():
    xk =  k
    for a in cache["EXKEYS"][k].keys():
        if re.search(r'^%s' % a, args.arch):
            xk = cache["EXKEYS"][k][a]
            break
    regexp += "s|\@%s\@|%s|g;" % (k,v)

try: os.listdir(dir)
except Exception as e: print(e, "Can not open directory for reading: %s" % f)
files = [f for f in os.listdir(dir)]
for file in files:
    if re.search(r'^CVS$', file): continue
    if re.search(r'^\.', file): continue
    fpath = os.path.join(dir, file)
    if not path.exists(fpath) or path.isdir(fpath) or path.islink(fpath): continue
    match = re.search("^%s_(.+)$" % args.project, file)
    if match: shutil.move(fpath, os.path.join(dir, match.group(1)))

for type in cache["SCRAMFILES"].keys():
    call("touch %s/XXX_%s; rm -f %s/*_%s*" % (dir, type, dir, type), shell=True)
call("find %s -name \"*\" -type f | xargs sed -i.backup$$ -e '%s'" % (dir,regexp), shell=True)
call("find %s -name '*.backup*' -type f | xargs rm -f" % dir, shell=True)
call("rm -rf %s/site;  echo %s > %s/scram_version" % (dir, args.scram, dir), shell=True)
