#!/bash/bin

  datasets='../datasets/'
  import='import/'
  exp='.tsv'
  mini='_Mini'

  if [[ ${1} = 2 ]]; then
    mini=''
  fi

  rm -rf $import
  mkdir $import

  cp ${datasets}Cards${mini}${exp} ${import}cards${exp}
  cp ${datasets}Checks${mini}${exp} ${import}checks${exp}
  cp ${datasets}Date_Of_Analysis_Formation${exp} ${import}date_of_analysis${exp}
  cp ${datasets}Groups_SKU${mini}${exp} ${import}sku_group${exp}
  cp ${datasets}Personal_Data${mini}${exp} ${import}personal_information${exp}
  cp ${datasets}SKU${mini}${exp} ${import}product_grid${exp}
  cp ${datasets}Stores${mini}${exp} ${import}stores${exp}
  cp ${datasets}Transactions${mini}${exp} ${import}transaction${exp}
