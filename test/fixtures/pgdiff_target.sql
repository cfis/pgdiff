CREATE SCHEMA target_schema;
CREATE SCHEMA shared_schema;

CREATE SEQUENCE target_sequence;
CREATE SEQUENCE shared_sequence;

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

