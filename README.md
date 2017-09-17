# oas-to-python
Master: [![Build Status](https://travis-ci.org/omerbn/oas-to-python.svg?branch=master)](https://travis-ci.org/omerbn/oas-to-python)
Generating .py files with py-objects and validators based on OAS files (YAML and JSON)
**Including references from other files!**
*(Currently OAS2.0 is supported)*

### Installation
[Python 3.6](https://www.python.org/downloads/release/python-362/) is required to run.

__pip__:
```sh
$ pip install git+https://github.com/omerbn/oas-to-python.git
```

### Usage
Command-line:

```sh
$ oas2python FILENAME --target=TARGET_FOLDER --models-library=PYTHON_MODELS_LIB --overwrite=True/False
```
In Python:
```sh
import oas2python

oas2python.entrypoint_viacode('./myfile.yml',
                              overwrite=True,
                              target_folder='./target_folder/',
                              models_lib='mylib.models')
```

| arg | description |
| ------ | ------ |
| filename | file path to process |
| overwrite | overwrite existing output files |
| target_folder (--target) | target folder of output files |
| models_lib (--models-lib) | python models lib which inlucdes the required models files|


### Example

##### target_file.yml:

```sh
swagger: '2.0'
info:
  version: '1.0'
schemes:
 - https
paths:
  /request:
    post:
      parameters:
        - in: body
          name: data
          schema:
            $ref: "#/definitions/RequestBody"
      responses:
        200:
          description: "OK"
          schema:
            $ref: "#/definitions/ResponseBody"

definitions:
  Error:
    type: object
    properties:
      error:
        type: string
        description: "Error message"
  RequestBody:
    type: object
    properties:
      session-type:
        $ref: "models:filename/sessionType"
      username:
        type: string
  ResponseBody:
    type: object
    properties:
      error:
        $ref: "#/definitions/Error"
      results:
        $ref: "models:filename/Results"

```

##### target\_folder/target\_file\_compiled.py:
```sh
from models_lib.compiled_filename import sessionType
from models_lib.compiled_filename import Results
...
class Error(object):
    ...
    def validate(json_data):
        """ validates json object according to jsonschema"""
    def get_object(*args):
        """ returns python-class instance according to jsonschema """
    ---
class RequestBody(object):
    ...
    def validate(json_data):
        """ validates json object according to jsonschema"""
    def get_object(*args):
        """ returns python-class instance according to jsonschema """
    ---
class ResponseBody(object):
    ...
    def validate(json_data):
        """ validates json object according to jsonschema"""
    def get_object(*args):
        """ returns python-class instance according to jsonschema """
    ---
```



### Multiple files
Please note that you need to build each file at a time

### Development

Want to contribute? Great!
Fell free to make pull requests

### License
GNU GPL 3.0



**Free Software, Hell Yeah!**