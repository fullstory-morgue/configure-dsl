#!/bin/bash

{
bash --dump-po-strings bin/pppconf-config

} | msguniq > po-pppconf/pppconf-config.pot
