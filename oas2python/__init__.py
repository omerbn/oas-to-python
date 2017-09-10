# -*- coding: utf-8 -*-

from argparse import ArgumentParser, Namespace
import os
from .process import process_file as _process_file


# reading arguments
def __main__():
    parser = ArgumentParser()
    parser.add_argument("filename", help="OAS File location", type=str)
    parser.add_argument("-t", "--target", dest="target_folder", help="Target Folder", type=str, default="")
    parser.add_argument("--models-folder", dest="models_folder", help="Common models folder", type=str, default=None)
    parser.add_argument("--models-library", dest="models_lib", help="Common models python-lib", type=str, default=None)
    parser.add_argument("--overwrite", dest="overwrite", help="overwriting existing files", type=bool, default=False)

    parser.add_argument("--api-generate", dest="api_generate", help="To Generate API?", type=bool, default=False)
    parser.add_argument("--api-folder", dest="api_folder", help="API generated folder name", type=str, default="api")
    # parser.add_argument("--api-framework", dest="framework", help="Swagger framework. default: sanic", type=str,
    #                    default="sanic")
    args = parser.parse_args()
    print("Processing %s into folder %s" % (args.filename, args.target_folder))
    __internal_run(args)


def process_file(filename, **argv):
    args = Namespace()
    setattr(args, 'filename', filename)
    setattr(args, 'target_folder', argv.get('target_folder', ""))
    setattr(args, 'models_folder', argv.get('models_folder', None))
    setattr(args, 'models_lib', argv.get('models_lib', None))
    setattr(args, 'overwrite', argv.get('overwrite', False))
    setattr(args, 'api_generate', argv.get('api_generate', False))
    setattr(args, 'api_folder', argv.get('api_folder', 'api'))
    __internal_run(args)


def __internal_run(args):
    # checking if file exists
    if not os.path.exists(args.filename):
        print("OAS file is missing")
        exit(1)

    # installing generator
    os.system('pip install python-jsonschema-objects')
    if args.api_generate and False:
        os.system('pip install swagger_py_codegen')
        os.system(
            'swagger_py_codegen --swagger-doc ' + args.filename + ' . -p ' + args.api_folder + ' --ui --spec --templates sanic')
        os.system('pip install -r requirements.txt')

        # creating sym. link to models folder
        if args.models_lib is not None:
            import importlib
            my_module = importlib.import_module(args.models_lib)
            if not my_module:
                raise ImportError("Invalid import " + args.models_lib)
            models_folder = os.path.abspath(os.path.dirname(my_module.__file__))
            os.system('mklink /D models "' + models_folder + '"')
        elif args.models_folder is not None:
            models_folder = os.path.abspath(os.path.dirname(args.models_folder))
            os.system('mklink /D models "' + models_folder + '"')

    # processing file
    _process_file(args)

    # removing sym. link to models folder
    if args.api_generate and False:
        os.system('rmdir models')
