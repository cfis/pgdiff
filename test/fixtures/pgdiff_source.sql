CREATE SCHEMA source_schema;
CREATE SCHEMA shared_schema;

CREATE SEQUENCE source_sequence;
CREATE SEQUENCE shared_sequence;

CREATE DOMAIN source_domain AS integer CHECK (VALUE < 0);
CREATE DOMAIN shared_domain AS integer CHECK (VALUE > 0);

CREATE TABLE IF NOT EXISTS source_table
(
    id integer NOT NULL PRIMARY KEY,
    first_name text NOT NULL,
    last_name text NOT NULL
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
    distance float NOT NULL,
    start_location text NOT NULL,
    finish_location text NOT NULL
);

CREATE TABLE IF NOT EXISTS shared_table_attribute_order
(
    id integer NOT NULL PRIMARY KEY,
    name text NOT NULL,
    distance float NOT NULL,
    start_location text NOT NULL,
    finish_location text NOT NULL
);

CREATE TABLE IF NOT EXISTS shared_table_constraints
(
    id integer NOT NULL,
    street text NOT NULL,
    city text NOT NULL,
    code text NOT NULL
);
