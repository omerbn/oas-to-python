# -*- coding: utf-8 -*-

# imports
{% for key, value in refs.items() %}
from {{value[0]}} import {{value[1]}}
{% endfor %}
import jsonschema
import json
import python_jsonschema_objects.classbuilder as classbuilder
import contextlib
from enum import Enum, auto

{% for def_name, def_value in definitions.items() %}
class {{def_name}}(object):
    _cls = None
    _schema = None

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
        _RESOLVED_PJS["{{def_name}}"] = {{def_name}}._schema

    @staticmethod
    def init():
        scheme_for_pjs = {{def_name}}._schema

        # is this just a 'fork' of another class?
        if '$ref' in scheme_for_pjs:
            forked = eval(scheme_for_pjs['$ref'][7:])
            {{def_name}}._cls = forked._cls
        else:
            scheme_for_pjs['title'] = "test"

            builder = classbuilder.ClassBuilder(_Resolver())
            builder.construct("{{def_name}}", scheme_for_pjs, **{"strict": False})
            {{def_name}}._cls = builder.resolved["{{def_name}}"]

    @staticmethod
    def validate(data):
        jsonschema.validate(data, {{def_name}}._schema, resolver=_Resolver())

    @staticmethod
    def schema():
        return {{def_name}}._schema

    @staticmethod
    def get_object(*args):
        return {{def_name}}._cls(*args)

    @staticmethod
    def get_resolver_cls():
        return _Resolver

{% endfor %}

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
        resolver = self._scopes[self._scope_index]

        # if current resolver is THIS instance:
        # using this reference
        if resolver == self:
            cls = eval(ref)
            resolver_class = cls.get_resolver_cls()

            # resolver class is the same as this instance's class, thus cannot bring something new to the table
            # Thus, not creating a new instance
            if resolver_class == _Resolver:
                return self, cls.schema()
            else:
                return resolver_class(), cls.schema()
        else: # else: using the 'other' resolver
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


# global 'resolved'
_RESOLVED_PJS = {
{% for key, value in refs.items() %}
    "{{value[1]}}": {{value[1]}}.schema(),
{% endfor %}
}

# registering all classes
{% for def_name, def_value in definitions.items() %}
{{def_name}}.register()
{% endfor %}

# initiating all classes
{% for def_name, def_value in definitions.items() %}
{{def_name}}.init()
{% endfor %}