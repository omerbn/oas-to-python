from distutils.core import setup

version = '0.1'

setup(
    name='oas-to-python',
    version=version,
    package_dir={'oas2python': 'oas2python'},
    packages=['oas2python'],
    url='https://github.com/omerbn/oas-to-python',
    license='GNU GPL 3.0',
    author='Omer Ben-Nahum',
    author_email='bn.omer@gmail.com',
    description='OAS to python',
    entry_points={
        "console_scripts": [
            "oas2python = oas2python:__main__",
        ]
    },
    package_data={'oas2python': ['template.tpl']},
    install_requires=['PyYAML',
                      "Jinja2",
                      "jsonschema"]
)
