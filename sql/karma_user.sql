--
-- create the read-only karma user
--
-- NOTE:  You do not have to run this script on your database if you don't
-- want to.  It's one way to guarentee that the tool WILL NOT MODIFY your
-- database.  You can also connect as sys/pass.
--
-- Pass in the password on the command line.
--


SET VERIFY OFF;

CREATE USER karma IDENTIFIED BY &karma_password
DEFAULT TABLESPACE tools
TEMPORARY TABLESPACE temp
QUOTA UNLIMITED ON tools;

GRANT CONNECT TO karma;
GRANT SELECT ANY TABLE TO karma;



