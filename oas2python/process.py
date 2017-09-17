# -*- coding: utf-8 -*-

import os
import yaml
import json
import codecs
from jinja2 import Template


def process_file(cmd_args):
    # target folder
    if cmd_args.target_folder:
        target_folder = os.path.abspath(os.path.dirname(cmd_args.target_folder))
    else:
        target_folder = os.path.abspath(os.path.dirname(cmd_args.filename))

    # target filename
    target_filename = _get_target_filename(cmd_args.filename, target_folder)

    # not overwriting existing file
    if os.path.exists(target_filename) and not cmd_args.overwrite:
        return

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
        # sorted_defs = [name for name, schema in defs.items()]
        global _nodes
        nodes = [DepNode(name) for name, schema in defs.items()]
        for name, schema in defs.items():
            import copy

            cl = RefCollector()
            schema_plain = copy.deepcopy(schema)
            cl.start(schema_plain, RefCollector.set_plain, nodes, DepNode.get_node(nodes, name))
            includes = cl.schemes

            schema_for_pjs = copy.deepcopy(schema)
            cl.start(schema_for_pjs, RefCollector.set_with_memory)

            defs[name] = {
                'schema': json.dumps(schema_plain),
                'schema_for_pjs': json.dumps(schema_for_pjs),
                'includes': [k[k.rfind('/') + 1:] for k, v in includes.items()]
            }

        # creating sorted defs
        sorted_defs = []
        while len(nodes):
            for x in nodes:
                if x.root == 0:
                    x.root = -1
                    sorted_defs.append(x.name)
                    for d in x.edges:
                        d.root -= 1
            nodes = [x for x in nodes if x.root != -1]

        with codecs.open(target_filename, 'w', 'utf-8') as fwd:
            # rendering template
            # fwd.write(template.tpl.render())
            template.stream(refs=refs, definitions=defs, sorted_definitions=sorted_defs).dump(fwd)


def _get_target_filename(source_filename, target_folder):
    target_filename = "compiled_" + os.path.splitext(os.path.basename(source_filename))[0] + ".py"
    return os.path.abspath(os.path.join(target_folder, target_filename))


class DepNode:
    def __init__(self, name):
        self.name = name
        self.edges = []
        self.root = 0

    def addDependee(self, node):
        node.root += 1
        self.edges.append(node)

    @staticmethod
    def get_node(nodes, name) -> "DepNode":
        return next((x for x in nodes if x.name == name), None)


class RefCollector(object):
    def __init__(self):
        self.schemes = {}
        self.my_node = None

    @staticmethod
    def set_plain(clsname):
        return clsname

    @staticmethod
    def set_with_memory(clsname):
        return "memory:" + clsname

    def start(self, node, handler, nodes=None, my_node=None):
        self.my_node = my_node
        self._rec(node, handler, nodes)

    def _rec(self, node, handler, nodes):
        if isinstance(node, dict):
            for k, v in node.items():
                if k == '$ref':
                    clsname = v[v.rfind('/') + 1:]
                    node[k] = handler(clsname)
                    self.schemes[v] = 1

                    if nodes and v.startswith("#/definitions/"):
                        target_node = DepNode.get_node(nodes, clsname)
                        target_node.addDependee(self.my_node)
                else:
                    self._rec(v, handler, nodes)
        elif isinstance(node, list):
            for x in node:
                self._rec(x, handler, nodes)
