--
-- create local karma objects to implement alertlog file scanning, 
-- as well as local OS stats
--
-- It is not necessary to create these objects in your database in
-- order to use Karma.  It merely allows you to monitor your alert log
-- as well as os statistics.
--

PROMPT Creating karma_os_stats table...
CREATE TABLE karma_os_stats (
	timestamp	DATE,
	load_one	NUMBER (5, 2),
	load_five	NUMBER (5, 2),
	load_fifteen	NUMBER (5, 2),
	pctidle		NUMBER (4, 1))
STORAGE (
	initial 	128k
	next		128k
	pctincrease	0
	minextents 	1
	maxextents 	unlimited);

PROMPT Creating karma_alertlog_errors table...
CREATE TABLE karma_alertlog_errors (
	timestamp	DATE,
        facility        varchar2(10),
        errno           number(10),
	text		varchar2(512))
STORAGE (
	initial		128k
	next		128k
	pctincrease	0
	minextents	1
	maxextents	unlimited);

	
PROMPT Creating karma_agent table...
CREATE TABLE karma_agent (
	id		varchar2(25),
	frequency	varchar2(3),
	timestamp	DATE)
STORAGE (
	initial 	128k
	next		128k
	pctincrease	0
	minextents 	1
	maxextents 	unlimited);

INSERT INTO karma_agent VALUES ('LASTUPDATE', '5', sysdate);
