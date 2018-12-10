# PL/pgSQL

***
check_text_type
====

The function checks text and if it is a numerical value, then it returns Boolean true.

***
order_upload
====

The procedure makes upload from Operation DB Source table in stage Hub and Satellite tables. After, it calls universal procedure for upload in target tables.
In this case you can increase the availability of target tables and reduce the risk of crashes while loading.

***
upload
====

The procedure makes upload to an any target table from source stage table. In the procedure are two ways for upload:
- increment type;
- full reload type;
It has two conditions:
- source and target tables must have columns with the same unique constraints:
-  core attributes in both tables must be the same.

***