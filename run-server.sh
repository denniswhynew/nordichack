#!/bin/bash

cd server
. venv/bin/activate
export FLASK_APP=nordichack.py
export FLASK_DEBUG=1

flask run --host=0.0.0.0

deactivate
cd ..
