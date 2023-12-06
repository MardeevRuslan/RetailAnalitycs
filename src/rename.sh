#!/bash/bin

mask='*.pgsql'
change='.sql'

  if [[ ${1} = 2 ]]; then
    mask='*.sql'
    change='.pgsql'
  fi


for file in $mask; do
    mv -- "$file" "${file%.*}${change}"
done