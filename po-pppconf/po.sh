#!/bin/bash

{
bash --dump-po-strings bin/my-pppconf

} | msguniq > po-pppconf/my-pppconf.pot
