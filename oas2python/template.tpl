# -*- coding: utf-8 -*-

# imports
{% for key, value in refs.items() %}
from {{value[0]}} import {{value[1]}}
{% endfor %}
import jsonschema
import json
import python_jsonschema_objects as pjs
from enum import Enum, auto

{% for def_name, def_value in definitions.items() %}
class {{def_name}}(object):
    _cls = None
    _schema = None
    _schema_pjs = None
    _pjs_resolved = None

    {% if def_value.enums %}
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
    class Enum_{{def_name}}(Enum):
        {% for key in def_value.enum %}
        {{key}} = auto()
        {% endfor %}

        def __str__(self):
            return str(self.name)
    {% endif %}


    @staticmethod
    def init():
        # SAVING SCHEME
        {{def_name}}._schema = json.loads("""{{def_value.schema}}""")

        # CREATING OBJECT
        {{def_name}}._schema_pjs = scheme_for_pjs = json.loads("""{{def_value.schema_for_pjs}}""")

        # is this just a 'fork' of another class?
        if '$ref' in scheme_for_pjs and scheme_for_pjs['$ref'].startswith('memory:'):
            forked = eval(scheme_for_pjs['$ref'][7:])
            {{def_name}}._cls = forked._cls
            {{def_name}}._pjs_resolved = forked._pjs_resolved
        else:
            # RESOLVING LINKS
            combined = {
                {% for include_class in def_value.includes %}
                    '{{include_class}}': {{include_class}}.schema_for_pjs(),
                {% endfor %}
            }
            {% for include_class in def_value.includes %}
            combined = {**combined, **{{include_class}}.pjs_resolved()}
            {% endfor %}
            {{def_name}}._pjs_resolved = combined

            scheme_for_pjs['title'] = "test"
            builder = pjs.ObjectBuilder(scheme_for_pjs, resolved=combined)
            {{def_name}}._cls = getattr(builder.build_classes(), "Test")

    @staticmethod
    def validate(data):
        jsonschema.validate(data, {{def_name}}._schema, resolver=_Resolver())

    @staticmethod
    def schema():
        return {{def_name}}._schema

    @staticmethod
    def schema_for_pjs():
        return {{def_name}}._schema_pjs

    @staticmethod
    def pjs_resolved():
        return {{def_name}}._pjs_resolved

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



# initiating all classes
{% for def in sorted_definitions %}
{{def}}.init()
{% endfor %}