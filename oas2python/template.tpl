# -*- coding: utf-8 -*-

import jsonschema
import json
import python_jsonschema_objects.classbuilder as classbuilder
import contextlib
from copy import deepcopy
from enum import Enum, auto


class _Resolver(object):
    def __init__(self):
        self._scopes = [self]
        self._scope_index = 0

    def push_scope(self, scope):
        self._scopes.append(scope)
        self._scope_index += 1

    def pop_scope(self):
        self._scopes.pop()
        self._scope_index -= 1

    def resolve(self, ref):
        # trying to resolve with THIS instance:
        if ref in _RESOLVED:
            cls = _RESOLVED[ref]
            resolver_class = cls.get_resolver_cls()

            # resolver class is the same as this instance's class, thus cannot bring something new to the table
            # Thus, not creating a new instance
            if resolver_class == _Resolver:
                return self, cls.schema()
            else:
                return resolver_class(), cls.schema()
        else:
            # using resolver in pipe
            resolver = self._scopes[self._scope_index]
            if resolver == self:
                return None,None
            else:
                return resolver.resolve(ref)

    @contextlib.contextmanager
    def resolving(self, ref):
        """
        Context manager which resolves a JSON ``ref`` and enters the
        resolution scope of this ref.

        Arguments:

            ref (str):

                The reference to resolve

        """

        url, resolved = self.resolve(ref)
        self.push_scope(url)
        try:
            yield resolved
        finally:
            self.pop_scope()

    @property
    def resolution_scope(*p, **kwargs):
        return ""

{% for def_name, def_value in definitions.items() %}
class {{def_name}}(object):
    _cls = None
    _schema = None
    _compiled_schema = None
    _initiated = False

    {% if def_value.enums %}
    # inline in-depth enums
    {% for enum_name, values in def_value.enums.items() %}
    class Enum_{{enum_name}}(Enum):
        {% for key in values %}
        {{key}} = auto()
        {% endfor %}

        def __str__(self):
            return str(self.name)
    {% endfor %}
    {% endif %}

    {% if def_value.enum %}
    # class is an enum
    class Enum_{{def_name}}(Enum):
        {% for key in def_value.enum %}
        {{key}} = auto()
        {% endfor %}

        def __str__(self):
            return str(self.name)
    {% endif %}


    @staticmethod
    def register():
        # SAVING SCHEME
        {{def_name}}._schema = json.loads("""{{def_value.schema}}""")

        # REGISTERING IN GLOBAL
        _RESOLVED["{{def_name}}"] = {{def_name}}

    @staticmethod
    def init():
        if {{def_name}}._initiated:
            return
        {{def_name}}._initiated = True

        scheme_for_pjs = deepcopy({{def_name}}._schema)

        # is this just a 'fork' of another class?
        if '$ref' in scheme_for_pjs:
            forked = eval(scheme_for_pjs['$ref'])
            {{def_name}}._cls = forked._cls
            {{def_name}}._compiled_schema = forked._compiled_schema
        else:
            scheme_for_pjs['title'] = "test"

            BUILDER.construct("{{def_name}}", scheme_for_pjs, **{"strict": False})
            {{def_name}}._cls = BUILDER.resolved["{{def_name}}"]
            {{def_name}}._compiled_schema = scheme_for_pjs

    @staticmethod
    def validate(data):
        jsonschema.validate(data, {{def_name}}._schema, resolver=_Resolver())

    @staticmethod
    def schema():
        {{def_name}}.init()
        return deepcopy({{def_name}}._schema)

    @staticmethod
    def complied_schema():
        {{def_name}}.init()
        return {{def_name}}._compiled_schema

    @staticmethod
    def get_object(*args):
        {{def_name}}.init()
        return {{def_name}}._cls(*args)

    @staticmethod
    def get_resolver_cls():
        return _Resolver

{% endfor %}


# global 'resolved'
_RESOLVED = {}

# builder
BUILDER = classbuilder.ClassBuilder(_Resolver())

# registering all classes
{% for def_name, def_value in definitions.items() %}
{{def_name}}.register()
{% endfor %}

# registering imports
{% for key, value in refs.items() %}
from {{value[0]}} import {{value[1]}}
_RESOLVED["{{value[1]}}"] = {{value[1]}}
{% endfor %}

# initiating all classes
{% for def_name, def_value in definitions.items() %}
{{def_name}}.init()
{% endfor %}