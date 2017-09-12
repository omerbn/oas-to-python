# -*- coding: utf-8 -*-

from argparse import ArgumentParser, Namespace
import os
from .process import process_file as _process_file


# reading arguments
def __main__():
    parser = ArgumentParser()
    parser.add_argument("filename", help="OAS File location", type=str)
    parser.add_argument("-t", "--target", dest="target_folder", help="Target Folder", type=str, default="")
    parser.add_argument("--models-library", dest="models_lib", help="Common models python-lib", type=str, default=None)
    parser.add_argument("--overwrite", dest="overwrite", help="overwriting existing files", type=bool, default=False)

    args = parser.parse_args()
    print("Processing %s into folder %s" % (args.filename, args.target_folder))
    __internal_run(args)


def process_file(filename, **argv):
    args = Namespace()
    setattr(args, 'filename', filename)
    setattr(args, 'target_folder', argv.get('target_folder', ""))
    setattr(args, 'models_lib', argv.get('models_lib', None))
    setattr(args, 'overwrite', argv.get('overwrite', False))
    __internal_run(args)


def __internal_run(args):
    # checking if file exists
    if not os.path.exists(args.filename):
        print("OAS file is missing")
        exit(1)

    # processing file
    _process_file(args)
