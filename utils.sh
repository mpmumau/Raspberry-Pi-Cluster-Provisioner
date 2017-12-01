#
# Utils.sh
#
# A useful set of general utility functions for use with Bash.
#
# Created: 11-30-2017
# Author: Matt Mumau <mpmumau@gmail.com>
#

# Count the number of elements in an array.
# Note: Be sure to include the entire array when passing
# it to this function, e.g.: "${array[@]}"
function array_count()
{
    a=("$@")
    n=0

    while [ "x${a[n]}" != "x" ]
    do
       n=$(( $n + 1 ))
    done

    echo "$n"
}

# Replace a token surrounded by handlebars (e.g. {{}}) with a value within the 
# text of  the given file.
function replace_token()
{
    TOKEN=$1
    REPLACE=$2
    FILE=$3

    sed -i "s/{{$TOKEN}}/$REPLACE/g" $FILE
}