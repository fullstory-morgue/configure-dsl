#!/bin/bash

{
bash --dump-po-strings bin/configure-pppconf

} | msguniq > po-pppconf/configure-pppconf.pot
