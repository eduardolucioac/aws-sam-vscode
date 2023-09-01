#!/bin/bash

# echo -n "Commands you can use next" | \
# grep -q "Commands you can use next" && \
# echo " > ------------------- 
# BUILD
# SUCCESS A
# < ------------------- "; \
# echo -n > "BUILD_SUCCESS"; \
# echo " > ------------------- 
# BUILD
# SUCCESS B
# < ------------------- "; \
# exit 0

function f_test(){
    echo -n "0"
}

if [ "$(f_test \"maria\")" -eq 1 ]; then
    echo "BOM"
else
    echo "RUIM"
fi
