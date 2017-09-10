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

    @staticmethod
    def init():
        # SAVING SCHEME
        {{def_name}}._schema = json.loads("""{{def_value.schema}}""")


        # CREATING OBJECT
        scheme_for_pjs = json.loads("""{{def_value.schema_for_pjs}}""")

        if not scheme_for_pjs.get('title', None):
            scheme_for_pjs['title'] = "{{def_name}}"
        builder = pjs.ObjectBuilder(scheme_for_pjs, resolved={
            {% for include_class in def_value.includes %}
                '{{include_class}}': {{include_class}}.schema(),
            {% endfor %}
        })
        {{def_name}}._cls = getattr(builder.build_classes(), "{{def_name}}".lower().title())

    @staticmethod
    def validate(data):
        jsonschema.validate(data, {{def_name}}._schema, resolver=_Resolver.get())

    @staticmethod
    def schema():
        return {{def_name}}._schema

    @staticmethod
    def get_object():
        return {{def_name}}._cls()

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
{% for def_name, def_value in definitions.items() %}
{{def_name}}.init()
{% endfor %}


