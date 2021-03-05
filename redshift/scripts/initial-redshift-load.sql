-- initial-redshift-load.sql

COPY customer_dim FROM :customers_s3 
IAM_ROLE :iam_role 
DELIMITER ','
COMPUPDATE ON;

COPY film_dim FROM :films_s3 
IAM_ROLE :iam_role 
DELIMITER ','
COMPUPDATE ON;

COPY staff_dim FROM :staff_s3 
IAM_ROLE :iam_role 
DELIMITER ','
COMPUPDATE ON;

COPY date_dim FROM :dates_s3 
IAM_ROLE :iam_role 
DELIMITER ','
COMPUPDATE ON;

COPY sales_facts FROM :sales_s3 
IAM_ROLE :iam_role 
DELIMITER ','
COMPUPDATE ON;
