# -*- coding: utf-8 -*-

import os
import yaml
import json
import codecs
from jinja2 import Template
import jsonschema


def process_file(cmd_args):
    # target folder
    if cmd_args.target_folder:
        target_folder = os.path.abspath(os.path.dirname(cmd_args.target_folder))
    else:
        target_folder = os.path.abspath(os.path.dirname(cmd_args.filename))

    # target filename
    target_filename = _get_target_filename(cmd_args.filename, target_folder)

    # not overwriting existing file
    if os.path.exists(target_filename) and not cmd_args.overwrite and not cmd_args.api_generate:
        exit(0)

    # template
    with codecs.open(os.path.join(os.path.dirname(__file__), 'template.tpl'), 'r', 'utf-8') as fd:
        template = Template(fd.read())

    # reading file
    with codecs.open(cmd_args.filename, 'r', 'utf-8') as fd:
        content = fd.read()
        is_yaml = cmd_args.filename.endswith('.yml') or cmd_args.filename.endswith('.yaml')
        is_json = cmd_args.filename.endswith('.js') or cmd_args.filename.endswith('.json')

        refs = {}
        ndx = content.find("$ref")
        while ndx != -1:
            ndx = content.find(":", ndx)
            if ndx == -1:
                raise ValueError("")
            ndx += 1
            # skipping whitespace
            while content[ndx].isspace():
                ndx += 1
            ending_char = None
            if content[ndx] == "'":
                ending_char = "'"
                ndx += 1
            elif content[ndx] == '"':
                ending_char = '"'
                ndx += 1

            if ending_char:
                end_ndx = content.find(ending_char, ndx)
            else:
                end_ndx = ndx
                while not content[end_ndx].isspace():
                    end_ndx += 1

            ref = content[ndx:end_ndx]
            if cmd_args.models_lib and ref.startswith("models:"):
                ref = ref.replace("models:", cmd_args.models_lib + ".compiled_")
                if ndx == -1:
                    continue
                if refs.get(ref, None):
                    continue
                refs[ref] = ref.split('/')
            ndx = content.find("$ref", end_ndx)

        if is_yaml:
            api_file_dict = yaml.load(content)
        elif is_json:
            api_file_dict = json.loads(content)
        else:
            raise ValueError("invalid file type")

        defs = api_file_dict.get('definitions', {})
        sorted_defs = []
        for name, schema in defs.items():
            import copy

            cl = RefCollector()
            schema_plain = copy.deepcopy(schema)
            cl.start(schema_plain, RefCollector.set_plain)
            includes = cl.schemes

            sorted_defs.append((name, cl.in_document_depends))

            schema_for_pjs = copy.deepcopy(schema)
            cl.start(schema_for_pjs, RefCollector.set_with_memory)

            defs[name] = {
                'schema': json.dumps(schema_plain),
                'schema_for_pjs': json.dumps(schema_for_pjs),
                'includes': [k[k.rfind('/') + 1:] for k, v in includes.items()]
            }

        def get_key(item):
            return item[1]
        sorted_defs = sorted(sorted_defs, key=get_key)

        with codecs.open(target_filename, 'w', 'utf-8') as fwd:
            # rendering template
            # fwd.write(template.tpl.render())
            template.stream(refs=refs, definitions=defs, sorted_definitions=sorted_defs).dump(fwd)

            # if args.api_generate and False:
            #    inject_into_api()


def _get_target_filename(source_filename, target_folder):
    target_filename = "compiled_" + os.path.splitext(os.path.basename(source_filename))[0] + ".py"
    return os.path.abspath(os.path.join(target_folder, target_filename))


class RefCollector(object):
    def __init__(self):
        self.schemes = {}
        self.in_document_depends = 0

    @staticmethod
    def set_plain(clsname):
        return clsname

    @staticmethod
    def set_with_memory(clsname):
        return "memory:" + clsname

    def start(self, node, handler):
        self.handler = handler
        self._rec(node)

    def _rec(self, node):
        if isinstance(node, dict):
            for k, v in node.items():
                if k == '$ref':
                    clsname = v[v.rfind('/') + 1:]
                    node[k] = self.handler(clsname)
                    self.schemes[v] = 1

                    if v.startswith("#/definitions/"):
                        self.in_document_depends += 1
                else:
                    self._rec(v)
        elif isinstance(node, list):
            for x in node:
                self._rec(x)
