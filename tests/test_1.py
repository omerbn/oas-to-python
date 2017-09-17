from oas2python import __main__, entrypoint_viacode
import sys
import os
from shutil import copyfile
import pytest

FIXTURE_DIR = os.path.join(
    os.path.dirname(os.path.realpath(__file__)),
    'data',
)
ALL_DATA_FILES = pytest.mark.datafiles(
    os.path.join(FIXTURE_DIR, 'example1.yml'),
)


@ALL_DATA_FILES
def test_overwrite_cli(datafiles):
    file = datafiles.listdir()[0]
    output_file = os.path.join(str(datafiles), "compiled_example1.py")
    sys.argv = [sys.argv[0],
                str(file),
                '--overwrite=true',
                # '--models-library=acurerate_common.models'
                ]
    __main__()
    time = os.path.getmtime(output_file)

    sys.argv = [sys.argv[0],
                str(file),
                # '--models-library=acurerate_common.models',
                ]
    __main__()
    assert (time == os.path.getmtime(output_file))


@ALL_DATA_FILES
def test_overwrite_code(datafiles):
    file = datafiles.listdir()[0]
    output_file = os.path.join(str(datafiles), "compiled_example1.py")

    entrypoint_viacode(str(file), overwrite=True)
    time = os.path.getmtime(output_file)
    entrypoint_viacode(str(file))

    assert (time == os.path.getmtime(output_file))
