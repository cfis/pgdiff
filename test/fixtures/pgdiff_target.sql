CREATE SCHEMA target_schema;
CREATE SCHEMA shared_schema;

CREATE SEQUENCE target_sequence;
CREATE SEQUENCE shared_sequence;

CREATE DOMAIN target_domain AS text
COLLATE pg_catalog."default"
CHECK(VALUE ~ '^\d{5}$' OR VALUE ~ '^\d{5}-\d{4}$')
CONSTRAINT length CHECK(LENGTH(VALUE) <= 10);

CREATE DOMAIN shared_domain AS integer CHECK (VALUE > 0);

CREATE TABLE IF NOT EXISTS target_table
(
    id integer NOT NULL PRIMARY KEY,
    genus text NOT NULL,
    species text NOT NULL
);

CREATE TABLE IF NOT EXISTS shared_table
(
    id integer NOT NULL PRIMARY KEY,
    street text NOT NULL,
    city text NOT NULL,
    code text NOT NULL
);

CREATE TABLE IF NOT EXISTS shared_table_attribute_types
(
    id integer NOT NULL PRIMARY KEY,
    name text NOT NULL,
    distance integer NOT NULL,
    start_location text NOT NULL,
    finish_location text NOT NULL
);

CREATE TABLE IF NOT EXISTS shared_table_attribute_order
(
    id integer NOT NULL PRIMARY KEY,
    name text NOT NULL,
    start_location text NOT NULL,
    finish_location text NOT NULL,
    distance int NOT NULL
);

CREATE TABLE IF NOT EXISTS shared_table_constraints
(
    id integer NOT NULL PRIMARY KEY,
    street text NOT NULL,
    city text NOT NULL,
    code text NOT NULL
);
