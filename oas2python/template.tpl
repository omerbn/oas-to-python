# -*- coding: utf-8 -*-

# imports
{% for key, value in refs.items() %}
from {{value[0]}} import {{value[1]}}
{% endfor %}
import jsonschema
import json
import python_jsonschema_objects as pjs

{% for def_name, def_value in definitions.items() %}
class {{def_name}}(object):
    _cls = None
    _schema = None
    _schema_pjs = None
    _pjs_resolved = None

    @staticmethod
    def init():
        # SAVING SCHEME
        {{def_name}}._schema = json.loads("""{{def_value.schema}}""")

        # CREATING OBJECT
        {{def_name}}._schema_pjs = scheme_for_pjs = json.loads("""{{def_value.schema_for_pjs}}""")

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
        jsonschema.validate(data, {{def_name}}._schema, resolver=_Resolver.get())

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

{% endfor %}
class _Resolver(object):
    _singleton = None

    def push_scope(self, scope):
        return

    def pop_scope(self):
        return

    def resolve(self, ref):
        return ref, eval(ref).schema()

    @staticmethod
    def get():
        if not _Resolver._singleton:
            _Resolver._singleton = _Resolver()
        return _Resolver._singleton


# initiating all classes
{% for def in sorted_definitions %}
{{def}}.init()
{% endfor %}