create table idx_servers_loc_node
(
    nodeno INTEGER
        primary key,
    data
);

create table idx_servers_loc_parent
(
    nodeno INTEGER
        primary key,
    parentnode
);

create table idx_servers_loc_rowid
(
    rowid INTEGER
        primary key,
    nodeno
);

create table servers
(
    id INT
        primary key,
    ip_address VARCHAR(45),
    name VARCHAR(255),
    domain VARCHAR(255),
    country VARCHAR(255),
    load INT,
    f_openvpn_udp INT,
    f_openvpn_tcp INT,
    f_wireguard_udp INT,
    updated_at TEXT,
    loc POINT
);

CREATE TRIGGER "ggi_servers_loc" BEFORE INSERT ON "servers"
    FOR EACH ROW BEGIN
    SELECT RAISE(ROLLBACK, 'servers.loc violates Geometry constraint [geom-type or SRID not allowed]')
    WHERE (SELECT geometry_type FROM geometry_columns
           WHERE Lower(f_table_name) = Lower('servers') AND Lower(f_geometry_column) = Lower('loc')
             AND GeometryConstraints(NEW."loc", geometry_type, srid) = 1) IS NULL;
END;

CREATE TRIGGER "ggu_servers_loc" BEFORE UPDATE OF "loc" ON "servers"
    FOR EACH ROW BEGIN
    SELECT RAISE(ROLLBACK, 'servers.loc violates Geometry constraint [geom-type or SRID not allowed]')
    WHERE (SELECT geometry_type FROM geometry_columns
           WHERE Lower(f_table_name) = Lower('servers') AND Lower(f_geometry_column) = Lower('loc')
             AND GeometryConstraints(NEW."loc", geometry_type, srid) = 1) IS NULL;
END;

CREATE TRIGGER "gid_servers_loc" AFTER DELETE ON "servers"
    FOR EACH ROW BEGIN
    DELETE FROM "idx_servers_loc" WHERE pkid=OLD.ROWID;
END;

CREATE TRIGGER "gii_servers_loc" AFTER INSERT ON "servers"
    FOR EACH ROW BEGIN
    DELETE FROM "idx_servers_loc" WHERE pkid=NEW.ROWID;
    SELECT RTreeAlign('idx_servers_loc', NEW.ROWID, NEW."loc");
END;

CREATE TRIGGER "giu_servers_loc" AFTER UPDATE OF "loc" ON "servers"
    FOR EACH ROW BEGIN
    DELETE FROM "idx_servers_loc" WHERE pkid=NEW.ROWID;
    SELECT RTreeAlign('idx_servers_loc', NEW.ROWID, NEW."loc");
END;

CREATE TRIGGER "tmd_servers_loc" AFTER DELETE ON "servers"
    FOR EACH ROW BEGIN
    UPDATE geometry_columns_time SET last_delete = strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
    WHERE Lower(f_table_name) = Lower('servers') AND Lower(f_geometry_column) = Lower('loc');
END;

CREATE TRIGGER "tmi_servers_loc" AFTER INSERT ON "servers"
    FOR EACH ROW BEGIN
    UPDATE geometry_columns_time SET last_insert = strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
    WHERE Lower(f_table_name) = Lower('servers') AND Lower(f_geometry_column) = Lower('loc');
END;

CREATE TRIGGER "tmu_servers_loc" AFTER UPDATE ON "servers"
    FOR EACH ROW BEGIN
    UPDATE geometry_columns_time SET last_update = strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
    WHERE Lower(f_table_name) = Lower('servers') AND Lower(f_geometry_column) = Lower('loc');
END;

create table spatial_ref_sys
(
    srid INTEGER not null
        primary key,
    auth_name TEXT not null,
    auth_srid INTEGER not null,
    ref_sys_name TEXT default 'Unknown' not null,
    proj4text TEXT not null,
    srtext TEXT default 'Undefined' not null
);

create table geometry_columns
(
    f_table_name TEXT not null,
    f_geometry_column TEXT not null,
    geometry_type INTEGER not null,
    coord_dimension INTEGER not null,
    srid INTEGER not null
        constraint fk_gc_srs
            references spatial_ref_sys,
    spatial_index_enabled INTEGER not null,
    constraint pk_geom_cols
        primary key (f_table_name, f_geometry_column),
    constraint ck_gc_rtree
        check (spatial_index_enabled IN (0,1,2))
);

create index idx_srid_geocols
    on geometry_columns (srid);

CREATE TRIGGER geometry_columns_coord_dimension_insert
    BEFORE INSERT ON 'geometry_columns'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'coord_dimension must be one of 2,3,4')
    WHERE NOT(NEW.coord_dimension IN (2,3,4));
END;

CREATE TRIGGER geometry_columns_coord_dimension_update
    BEFORE UPDATE OF 'coord_dimension' ON 'geometry_columns'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'coord_dimension must be one of 2,3,4')
    WHERE NOT(NEW.coord_dimension IN (2,3,4));
END;

CREATE TRIGGER geometry_columns_f_geometry_column_insert
    BEFORE INSERT ON 'geometry_columns'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'insert on geometry_columns violates constraint: f_geometry_column value must not contain a single quote')
    WHERE NEW.f_geometry_column LIKE ('%''%');
    SELECT RAISE(ABORT,'insert on geometry_columns violates constraint:
f_geometry_column value must not contain a double quote')
    WHERE NEW.f_geometry_column LIKE ('%"%');
    SELECT RAISE(ABORT,'insert on geometry_columns violates constraint: f_geometry_column value must be lower case')
    WHERE NEW.f_geometry_column <> lower(NEW.f_geometry_column);
END;

CREATE TRIGGER geometry_columns_f_geometry_column_update
    BEFORE UPDATE OF 'f_geometry_column' ON 'geometry_columns'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'update on geometry_columns violates constraint: f_geometry_column value must not contain a single quote')
    WHERE NEW.f_geometry_column LIKE ('%''%');
    SELECT RAISE(ABORT,'update on geometry_columns violates constraint: f_geometry_column value must not contain a double quote')
    WHERE NEW.f_geometry_column LIKE ('%"%');
    SELECT RAISE(ABORT,'update on geometry_columns violates constraint: f_geometry_column value must be lower case')
    WHERE NEW.f_geometry_column <> lower(NEW.f_geometry_column);
END;

CREATE TRIGGER geometry_columns_f_table_name_insert
    BEFORE INSERT ON 'geometry_columns'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'insert on geometry_columns violates constraint: f_table_name value must not contain a single quote')
    WHERE NEW.f_table_name LIKE ('%''%');
    SELECT RAISE(ABORT,'insert on geometry_columns violates constraint: f_table_name value must not contain a double quote')
    WHERE NEW.f_table_name LIKE ('%"%');
    SELECT RAISE(ABORT,'insert on geometry_columns violates constraint:
f_table_name value must be lower case')
    WHERE NEW.f_table_name <> lower(NEW.f_table_name);
END;

CREATE TRIGGER geometry_columns_f_table_name_update
    BEFORE UPDATE OF 'f_table_name' ON 'geometry_columns'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'update on geometry_columns violates constraint: f_table_name value must not contain a single quote')
    WHERE NEW.f_table_name LIKE ('%''%');
    SELECT RAISE(ABORT,'update on geometry_columns violates constraint: f_table_name value must not contain a double quote')
    WHERE NEW.f_table_name LIKE ('%"%');
    SELECT RAISE(ABORT,'update on geometry_columns violates constraint: f_table_name value must be lower case')
    WHERE NEW.f_table_name <> lower(NEW.f_table_name);
END;

CREATE TRIGGER geometry_columns_geometry_type_insert
    BEFORE INSERT ON 'geometry_columns'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'geometry_type must be one of 0,1,2,3,4,5,6,7,1000,1001,1002,1003,1004,1005,1006,1007,2000,2001,2002,2003,2004,2005,2006,2007,3000,3001,3002,3003,3004,3005,3006,3007')
    WHERE NOT(NEW.geometry_type IN (0,1,2,3,4,5,6,7,1000,1001,1002,1003,1004,1005,1006,1007,2000,2001,2002,2003,2004,2005,2006,2007,3000,3001,3002,3003,3004,3005,3006,3007));
END;

CREATE TRIGGER geometry_columns_geometry_type_update
    BEFORE UPDATE OF 'geometry_type' ON 'geometry_columns'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'geometry_type must be one of 0,1,2,3,4,5,6,7,1000,1001,1002,1003,1004,1005,1006,1007,2000,2001,2002,2003,2004,2005,2006,2007,3000,3001,3002,3003,3004,3005,3006,3007')
    WHERE NOT(NEW.geometry_type IN (0,1,2,3,4,5,6,7,1000,1001,1002,1003,1004,1005,1006,1007,2000,2001,2002,2003,2004,2005,2006,2007,3000,3001,3002,3003,3004,3005,3006,3007));
END;

create table geometry_columns_auth
(
    f_table_name TEXT not null,
    f_geometry_column TEXT not null,
    read_only INTEGER not null,
    hidden INTEGER not null,
    constraint pk_gc_auth
        primary key (f_table_name, f_geometry_column),
    constraint fk_gc_auth
        foreign key (f_table_name, f_geometry_column) references geometry_columns
            on delete cascade,
    constraint ck_gc_hidden
        check (hidden IN (0,1)),
    constraint ck_gc_ronly
        check (read_only IN (0,1))
);

CREATE TRIGGER gcau_f_geometry_column_insert
    BEFORE INSERT ON 'geometry_columns_auth'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'insert on geometry_columns_auth violates constraint: f_geometry_column value must not contain a single quote')
    WHERE NEW.f_geometry_column LIKE ('%''%');
    SELECT RAISE(ABORT,'insert on geometry_columns_auth violates constraint:
f_geometry_column value must not contain a double quote')
    WHERE NEW.f_geometry_column LIKE ('%"%');
    SELECT RAISE(ABORT,'insert on geometry_columns_auth violates constraint: f_geometry_column value must be lower case')
    WHERE NEW.f_geometry_column <> lower(NEW.f_geometry_column);
END;

CREATE TRIGGER gcau_f_geometry_column_update
    BEFORE UPDATE OF 'f_geometry_column' ON 'geometry_columns_auth'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'update on geometry_columns_auth violates constraint: f_geometry_column value must not contain a single quote')
    WHERE NEW.f_geometry_column LIKE ('%''%');
    SELECT RAISE(ABORT,'update on geometry_columns_auth violates constraint: f_geometry_column value must not contain a double quote')
    WHERE NEW.f_geometry_column LIKE ('%"%');
    SELECT RAISE(ABORT,'update on geometry_columns_auth violates constraint: f_geometry_column value must be lower case')
    WHERE NEW.f_geometry_column <> lower(NEW.f_geometry_column);
END;

CREATE TRIGGER gcau_f_table_name_insert
    BEFORE INSERT ON 'geometry_columns_auth'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'insert on geometry_columns_auth violates constraint: f_table_name value must not contain a single quote')
    WHERE NEW.f_table_name LIKE ('%''%');
    SELECT RAISE(ABORT,'insert on geometry_columns_auth violates constraint: f_table_name value must not contain a double quote')
    WHERE NEW.f_table_name LIKE ('%"%');
    SELECT RAISE(ABORT,'insert on geometry_columns_auth violates constraint:
f_table_name value must be lower case')
    WHERE NEW.f_table_name <> lower(NEW.f_table_name);
END;

CREATE TRIGGER gcau_f_table_name_update
    BEFORE UPDATE OF 'f_table_name' ON 'geometry_columns_auth'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'update on geometry_columns_auth violates constraint: f_table_name value must not contain a single quote')
    WHERE NEW.f_table_name LIKE ('%''%');
    SELECT RAISE(ABORT,'update on geometry_columns_auth violates constraint: f_table_name value must not contain a double quote')
    WHERE NEW.f_table_name LIKE ('%"%');
    SELECT RAISE(ABORT,'update on geometry_columns_auth violates constraint: f_table_name value must be lower case')
    WHERE NEW.f_table_name <> lower(NEW.f_table_name);
END;

create table geometry_columns_field_infos
(
    f_table_name TEXT not null,
    f_geometry_column TEXT not null,
    ordinal INTEGER not null,
    column_name TEXT not null,
    null_values INTEGER not null,
    integer_values INTEGER not null,
    double_values INTEGER not null,
    text_values INTEGER not null,
    blob_values INTEGER not null,
    max_size INTEGER,
    integer_min INTEGER,
    integer_max INTEGER,
    double_min DOUBLE,
    double_max DOUBLE,
    constraint pk_gcfld_infos
        primary key (f_table_name, f_geometry_column, ordinal, column_name),
    constraint fk_gcfld_infos
        foreign key (f_table_name, f_geometry_column) references geometry_columns
            on delete cascade
);

CREATE TRIGGER gcfi_f_geometry_column_insert
    BEFORE INSERT ON 'geometry_columns_field_infos'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'insert on geometry_columns_field_infos violates constraint: f_geometry_column value must not contain a single quote')
    WHERE NEW.f_geometry_column LIKE ('%''%');
    SELECT RAISE(ABORT,'insert on geometry_columns_field_infos violates constraint:
f_geometry_column value must not contain a double quote')
    WHERE NEW.f_geometry_column LIKE ('%"%');
    SELECT RAISE(ABORT,'insert on geometry_columns_field_infos violates constraint: f_geometry_column value must be lower case')
    WHERE NEW.f_geometry_column <> lower(NEW.f_geometry_column);
END;

CREATE TRIGGER gcfi_f_geometry_column_update
    BEFORE UPDATE OF 'f_geometry_column' ON 'geometry_columns_field_infos'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'update on geometry_columns_field_infos violates constraint: f_geometry_column value must not contain a single quote')
    WHERE NEW.f_geometry_column LIKE ('%''%');
    SELECT RAISE(ABORT,'update on geometry_columns_field_infos violates constraint: f_geometry_column value must not contain a double quote')
    WHERE NEW.f_geometry_column LIKE ('%"%');
    SELECT RAISE(ABORT,'update on geometry_columns_field_infos violates constraint: f_geometry_column value must be lower case')
    WHERE NEW.f_geometry_column <> lower(NEW.f_geometry_column);
END;

CREATE TRIGGER gcfi_f_table_name_insert
    BEFORE INSERT ON 'geometry_columns_field_infos'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'insert on geometry_columns_field_infos violates constraint: f_table_name value must not contain a single quote')
    WHERE NEW.f_table_name LIKE ('%''%');
    SELECT RAISE(ABORT,'insert on geometry_columns_field_infos violates constraint: f_table_name value must not contain a double quote')
    WHERE NEW.f_table_name LIKE ('%"%');
    SELECT RAISE(ABORT,'insert on geometry_columns_field_infos violates constraint:
f_table_name value must be lower case')
    WHERE NEW.f_table_name <> lower(NEW.f_table_name);
END;

CREATE TRIGGER gcfi_f_table_name_update
    BEFORE UPDATE OF 'f_table_name' ON 'geometry_columns_field_infos'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'update on geometry_columns_field_infos violates constraint: f_table_name value must not contain a single quote')
    WHERE NEW.f_table_name LIKE ('%''%');
    SELECT RAISE(ABORT,'update on geometry_columns_field_infos violates constraint: f_table_name value must not contain a double quote')
    WHERE NEW.f_table_name LIKE ('%"%');
    SELECT RAISE(ABORT,'update on geometry_columns_field_infos violates constraint: f_table_name value must be lower case')
    WHERE NEW.f_table_name <> lower(NEW.f_table_name);
END;

create table geometry_columns_statistics
(
    f_table_name TEXT not null,
    f_geometry_column TEXT not null,
    last_verified TIMESTAMP,
    row_count INTEGER,
    extent_min_x DOUBLE,
    extent_min_y DOUBLE,
    extent_max_x DOUBLE,
    extent_max_y DOUBLE,
    constraint pk_gc_statistics
        primary key (f_table_name, f_geometry_column),
    constraint fk_gc_statistics
        foreign key (f_table_name, f_geometry_column) references geometry_columns
            on delete cascade
);

CREATE TRIGGER gcs_f_geometry_column_insert
    BEFORE INSERT ON 'geometry_columns_statistics'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'insert on geometry_columns_statistics violates constraint: f_geometry_column value must not contain a single quote')
    WHERE NEW.f_geometry_column LIKE ('%''%');
    SELECT RAISE(ABORT,'insert on geometry_columns_statistics violates constraint:
f_geometry_column value must not contain a double quote')
    WHERE NEW.f_geometry_column LIKE ('%"%');
    SELECT RAISE(ABORT,'insert on geometry_columns_statistics violates constraint: f_geometry_column value must be lower case')
    WHERE NEW.f_geometry_column <> lower(NEW.f_geometry_column);
END;

CREATE TRIGGER gcs_f_geometry_column_update
    BEFORE UPDATE OF 'f_geometry_column' ON 'geometry_columns_statistics'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'update on geometry_columns_statistics violates constraint: f_geometry_column value must not contain a single quote')
    WHERE NEW.f_geometry_column LIKE ('%''%');
    SELECT RAISE(ABORT,'update on geometry_columns_statistics violates constraint: f_geometry_column value must not contain a double quote')
    WHERE NEW.f_geometry_column LIKE ('%"%');
    SELECT RAISE(ABORT,'update on geometry_columns_statistics violates constraint: f_geometry_column value must be lower case')
    WHERE NEW.f_geometry_column <> lower(NEW.f_geometry_column);
END;

CREATE TRIGGER gcs_f_table_name_insert
    BEFORE INSERT ON 'geometry_columns_statistics'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'insert on geometry_columns_statistics violates constraint: f_table_name value must not contain a single quote')
    WHERE NEW.f_table_name LIKE ('%''%');
    SELECT RAISE(ABORT,'insert on geometry_columns_statistics violates constraint: f_table_name value must not contain a double quote')
    WHERE NEW.f_table_name LIKE ('%"%');
    SELECT RAISE(ABORT,'insert on geometry_columns_statistics violates constraint:
f_table_name value must be lower case')
    WHERE NEW.f_table_name <> lower(NEW.f_table_name);
END;

CREATE TRIGGER gcs_f_table_name_update
    BEFORE UPDATE OF 'f_table_name' ON 'geometry_columns_statistics'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'update on geometry_columns_statistics violates constraint: f_table_name value must not contain a single quote')
    WHERE NEW.f_table_name LIKE ('%''%');
    SELECT RAISE(ABORT,'update on geometry_columns_statistics violates constraint: f_table_name value must not contain a double quote')
    WHERE NEW.f_table_name LIKE ('%"%');
    SELECT RAISE(ABORT,'update on geometry_columns_statistics violates constraint: f_table_name value must be lower case')
    WHERE NEW.f_table_name <> lower(NEW.f_table_name);
END;

create table geometry_columns_time
(
    f_table_name TEXT not null,
    f_geometry_column TEXT not null,
    last_insert TIMESTAMP default '0000-01-01T00:00:00.000Z' not null,
    last_update TIMESTAMP default '0000-01-01T00:00:00.000Z' not null,
    last_delete TIMESTAMP default '0000-01-01T00:00:00.000Z' not null,
    constraint pk_gc_time
        primary key (f_table_name, f_geometry_column),
    constraint fk_gc_time
        foreign key (f_table_name, f_geometry_column) references geometry_columns
            on delete cascade
);

CREATE TRIGGER gctm_f_geometry_column_insert
    BEFORE INSERT ON 'geometry_columns_time'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'insert on geometry_columns_time violates constraint: f_geometry_column value must not contain a single quote')
    WHERE NEW.f_geometry_column LIKE ('%''%');
    SELECT RAISE(ABORT,'insert on geometry_columns_time violates constraint:
f_geometry_column value must not contain a double quote')
    WHERE NEW.f_geometry_column LIKE ('%"%');
    SELECT RAISE(ABORT,'insert on geometry_columns_time violates constraint: f_geometry_column value must be lower case')
    WHERE NEW.f_geometry_column <> lower(NEW.f_geometry_column);
END;

CREATE TRIGGER gctm_f_geometry_column_update
    BEFORE UPDATE OF 'f_geometry_column' ON 'geometry_columns_time'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'update on geometry_columns_time violates constraint: f_geometry_column value must not contain a single quote')
    WHERE NEW.f_geometry_column LIKE ('%''%');
    SELECT RAISE(ABORT,'update on geometry_columns_time violates constraint: f_geometry_column value must not contain a double quote')
    WHERE NEW.f_geometry_column LIKE ('%"%');
    SELECT RAISE(ABORT,'update on geometry_columns_time violates constraint: f_geometry_column value must be lower case')
    WHERE NEW.f_geometry_column <> lower(NEW.f_geometry_column);
END;

CREATE TRIGGER gctm_f_table_name_insert
    BEFORE INSERT ON 'geometry_columns_time'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'insert on geometry_columns_time violates constraint: f_table_name value must not contain a single quote')
    WHERE NEW.f_table_name LIKE ('%''%');
    SELECT RAISE(ABORT,'insert on geometry_columns_time violates constraint: f_table_name value must not contain a double quote')
    WHERE NEW.f_table_name LIKE ('%"%');
    SELECT RAISE(ABORT,'insert on geometry_columns_time violates constraint:
f_table_name value must be lower case')
    WHERE NEW.f_table_name <> lower(NEW.f_table_name);
END;

CREATE TRIGGER gctm_f_table_name_update
    BEFORE UPDATE OF 'f_table_name' ON 'geometry_columns_time'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'update on geometry_columns_time violates constraint: f_table_name value must not contain a single quote')
    WHERE NEW.f_table_name LIKE ('%''%');
    SELECT RAISE(ABORT,'update on geometry_columns_time violates constraint: f_table_name value must not contain a double quote')
    WHERE NEW.f_table_name LIKE ('%"%');
    SELECT RAISE(ABORT,'update on geometry_columns_time violates constraint: f_table_name value must be lower case')
    WHERE NEW.f_table_name <> lower(NEW.f_table_name);
END;

create unique index idx_spatial_ref_sys
    on spatial_ref_sys (auth_srid, auth_name);

create table spatial_ref_sys_aux
(
    srid INTEGER not null
        primary key
        constraint fk_sprefsys
            references spatial_ref_sys,
    is_geographic INTEGER,
    has_flipped_axes INTEGER,
    spheroid TEXT,
    prime_meridian TEXT,
    datum TEXT,
    projection TEXT,
    unit TEXT,
    axis_1_name TEXT,
    axis_1_orientation TEXT,
    axis_2_name TEXT,
    axis_2_orientation TEXT
);

create table spatialite_history
(
    event_id INTEGER not null
        primary key autoincrement,
    table_name TEXT not null,
    geometry_column TEXT,
    event TEXT not null,
    timestamp TEXT not null,
    ver_sqlite TEXT not null,
    ver_splite TEXT not null
);

create table sql_statements_log
(
    id INTEGER
        primary key autoincrement,
    time_start TIMESTAMP default '0000-01-01T00:00:00.000Z' not null,
    time_end TIMESTAMP default '0000-01-01T00:00:00.000Z' not null,
    user_agent TEXT not null,
    sql_statement TEXT not null,
    success INTEGER default 0 not null,
    error_cause TEXT default 'ABORTED' not null,
    constraint sqllog_success
        check (success IN (0,1))
);

create table views_geometry_columns
(
    view_name TEXT not null,
    view_geometry TEXT not null,
    view_rowid TEXT not null,
    f_table_name TEXT not null,
    f_geometry_column TEXT not null,
    read_only INTEGER not null,
    constraint pk_geom_cols_views
        primary key (view_name, view_geometry),
    constraint fk_views_geom_cols
        foreign key (f_table_name, f_geometry_column) references geometry_columns
            on delete cascade,
    constraint ck_vw_rdonly
        check (read_only IN (0,1))
);

create index idx_viewsjoin
    on views_geometry_columns (f_table_name, f_geometry_column);

CREATE TRIGGER vwgc_f_geometry_column_insert
    BEFORE INSERT ON 'views_geometry_columns'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'insert on views_geometry_columns violates constraint: f_geometry_column value must not contain a single quote')
    WHERE NEW.f_geometry_column LIKE ('%''%');
    SELECT RAISE(ABORT,'insert on views_geometry_columns violates constraint:
f_geometry_column value must not contain a double quote')
    WHERE NEW.f_geometry_column LIKE ('%"%');
    SELECT RAISE(ABORT,'insert on views_geometry_columns violates constraint: f_geometry_column value must be lower case')
    WHERE NEW.f_geometry_column <> lower(NEW.f_geometry_column);
END;

CREATE TRIGGER vwgc_f_geometry_column_update
    BEFORE UPDATE OF 'f_geometry_column' ON 'views_geometry_columns'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'update on views_geometry_columns violates constraint: f_geometry_column value must not contain a single quote')
    WHERE NEW.f_geometry_column LIKE ('%''%');
    SELECT RAISE(ABORT,'update on views_geometry_columns violates constraint: f_geometry_column value must not contain a double quote')
    WHERE NEW.f_geometry_column LIKE ('%"%');
    SELECT RAISE(ABORT,'update on views_geometry_columns violates constraint: f_geometry_column value must be lower case')
    WHERE NEW.f_geometry_column <> lower(NEW.f_geometry_column);
END;

CREATE TRIGGER vwgc_f_table_name_insert
    BEFORE INSERT ON 'views_geometry_columns'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'insert on views_geometry_columns violates constraint: f_table_name value must not contain a single quote')
    WHERE NEW.f_table_name LIKE ('%''%');
    SELECT RAISE(ABORT,'insert on views_geometry_columns violates constraint: f_table_name value must not contain a double quote')
    WHERE NEW.f_table_name LIKE ('%"%');
    SELECT RAISE(ABORT,'insert on views_geometry_columns violates constraint:
f_table_name value must be lower case')
    WHERE NEW.f_table_name <> lower(NEW.f_table_name);
END;

CREATE TRIGGER vwgc_f_table_name_update
    BEFORE UPDATE OF 'f_table_name' ON 'views_geometry_columns'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'update on views_geometry_columns violates constraint: f_table_name value must not contain a single quote')
    WHERE NEW.f_table_name LIKE ('%''%');
    SELECT RAISE(ABORT,'update on views_geometry_columns violates constraint: f_table_name value must not contain a double quote')
    WHERE NEW.f_table_name LIKE ('%"%');
    SELECT RAISE(ABORT,'update on views_geometry_columns violates constraint: f_table_name value must be lower case')
    WHERE NEW.f_table_name <> lower(NEW.f_table_name);
END;

CREATE TRIGGER vwgc_view_geometry_insert
    BEFORE INSERT ON 'views_geometry_columns'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'insert on views_geometry_columns violates constraint: view_geometry value must not contain a single quote')
    WHERE NEW.view_geometry LIKE ('%''%');
    SELECT RAISE(ABORT,'insert on views_geometry_columns violates constraint:
view_geometry value must not contain a double quote')
    WHERE NEW.view_geometry LIKE ('%"%');
    SELECT RAISE(ABORT,'insert on views_geometry_columns violates constraint: view_geometry value must be lower case')
    WHERE NEW.view_geometry <> lower(NEW.view_geometry);
END;

CREATE TRIGGER vwgc_view_geometry_update
    BEFORE UPDATE OF 'view_geometry' ON 'views_geometry_columns'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'update on views_geometry_columns violates constraint: view_geometry value must not contain a single quote')
    WHERE NEW.view_geometry LIKE ('%''%');
    SELECT RAISE(ABORT,'update on views_geometry_columns violates constraint:
view_geometry value must not contain a double quote')
    WHERE NEW.view_geometry LIKE ('%"%');
    SELECT RAISE(ABORT,'update on views_geometry_columns violates constraint: view_geometry value must be lower case')
    WHERE NEW.view_geometry <> lower(NEW.view_geometry);
END;

CREATE TRIGGER vwgc_view_name_insert
    BEFORE INSERT ON 'views_geometry_columns'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'insert on views_geometry_columns violates constraint: view_name value must not contain a single quote')
    WHERE NEW.view_name LIKE ('%''%');
    SELECT RAISE(ABORT,'insert on views_geometry_columns violates constraint: view_name value must not contain a double quote')
    WHERE NEW.view_name LIKE ('%"%');
    SELECT RAISE(ABORT,'insert on views_geometry_columns violates constraint:
view_name value must be lower case')
    WHERE NEW.view_name <> lower(NEW.view_name);
END;

CREATE TRIGGER vwgc_view_name_update
    BEFORE UPDATE OF 'view_name' ON 'views_geometry_columns'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'update on views_geometry_columns violates constraint: view_name value must not contain a single quote')
    WHERE NEW.view_name LIKE ('%''%');
    SELECT RAISE(ABORT,'update on views_geometry_columns violates constraint: view_name value must not contain a double quote')
    WHERE NEW.view_name LIKE ('%"%');
    SELECT RAISE(ABORT,'update on views_geometry_columns violates constraint: view_name value must be lower case')
    WHERE NEW.view_name <> lower(NEW.view_name);
END;

CREATE TRIGGER vwgc_view_rowid_insert
    BEFORE INSERT ON 'views_geometry_columns'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'insert on views_geometry_columns violates constraint: view_rowid value must not contain a single quote')
    WHERE NEW.view_rowid LIKE ('%''%');
    SELECT RAISE(ABORT,'insert on views_geometry_columns violates constraint:
view_rowid value must not contain a double quote')
    WHERE NEW.view_rowid LIKE ('%"%');
    SELECT RAISE(ABORT,'insert on views_geometry_columns violates constraint: view_rowid value must be lower case')
    WHERE NEW.view_rowid <> lower(NEW.view_rowid);
END;

CREATE TRIGGER vwgc_view_rowid_update
    BEFORE UPDATE OF 'view_rowid' ON 'views_geometry_columns'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'update on views_geometry_columns violates constraint: view_rowid value must not contain a single quote')
    WHERE NEW.f_geometry_column LIKE ('%''%');
    SELECT RAISE(ABORT,'update on views_geometry_columns violates constraint: view_rowid value must not contain a double quote')
    WHERE NEW.view_rowid LIKE ('%"%');
    SELECT RAISE(ABORT,'update on views_geometry_columns violates constraint: view_rowid value must be lower case')
    WHERE NEW.view_rowid <> lower(NEW.view_rowid);
END;

create table views_geometry_columns_auth
(
    view_name TEXT not null,
    view_geometry TEXT not null,
    hidden INTEGER not null,
    constraint pk_vwgc_auth
        primary key (view_name, view_geometry),
    constraint fk_vwgc_auth
        foreign key (view_name, view_geometry) references views_geometry_columns
            on delete cascade,
    constraint ck_vwgc_hidden
        check (hidden IN (0,1))
);

CREATE TRIGGER vwgcau_view_geometry_insert
    BEFORE INSERT ON 'views_geometry_columns_auth'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'insert on views_geometry_columns_auth violates constraint: view_geometry value must not contain a single quote')
    WHERE NEW.view_geometry LIKE ('%''%');
    SELECT RAISE(ABORT,'insert on views_geometry_columns_auth violates constraint:
view_geometry value must not contain a double quote')
    WHERE NEW.view_geometry LIKE ('%"%');
    SELECT RAISE(ABORT,'insert on views_geometry_columns_auth violates constraint: view_geometry value must be lower case')
    WHERE NEW.view_geometry <> lower(NEW.view_geometry);
END;

CREATE TRIGGER vwgcau_view_geometry_update
    BEFORE UPDATE OF 'view_geometry'  ON 'views_geometry_columns_auth'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'update on views_geometry_columns_auth violates constraint: view_geometry value must not contain a single quote')
    WHERE NEW.view_geometry LIKE ('%''%');
    SELECT RAISE(ABORT,'update on views_geometry_columns_auth violates constraint:
view_geometry value must not contain a double quote')
    WHERE NEW.view_geometry LIKE ('%"%');
    SELECT RAISE(ABORT,'update on views_geometry_columns_auth violates constraint: view_geometry value must be lower case')
    WHERE NEW.view_geometry <> lower(NEW.view_geometry);
END;

CREATE TRIGGER vwgcau_view_name_insert
    BEFORE INSERT ON 'views_geometry_columns_auth'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'insert on views_geometry_columns_auth violates constraint: view_name value must not contain a single quote')
    WHERE NEW.view_name LIKE ('%''%');
    SELECT RAISE(ABORT,'insert on views_geometry_columns_auth violates constraint: view_name value must not contain a double quote')
    WHERE NEW.view_name LIKE ('%"%');
    SELECT RAISE(ABORT,'insert on views_geometry_columns_auth violates constraint:
view_name value must be lower case')
    WHERE NEW.view_name <> lower(NEW.view_name);
END;

CREATE TRIGGER vwgcau_view_name_update
    BEFORE UPDATE OF 'view_name' ON 'views_geometry_columns_auth'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'update on views_geometry_columns_auth violates constraint: view_name value must not contain a single quote')
    WHERE NEW.view_name LIKE ('%''%');
    SELECT RAISE(ABORT,'update on views_geometry_columns_auth violates constraint: view_name value must not contain a double quote')
    WHERE NEW.view_name LIKE ('%"%');
    SELECT RAISE(ABORT,'update on views_geometry_columns_auth violates constraint: view_name value must be lower case')
    WHERE NEW.view_name <> lower(NEW.view_name);
END;

create table views_geometry_columns_field_infos
(
    view_name TEXT not null,
    view_geometry TEXT not null,
    ordinal INTEGER not null,
    column_name TEXT not null,
    null_values INTEGER not null,
    integer_values INTEGER not null,
    double_values INTEGER not null,
    text_values INTEGER not null,
    blob_values INTEGER not null,
    max_size INTEGER,
    integer_min INTEGER,
    integer_max INTEGER,
    double_min DOUBLE,
    double_max DOUBLE,
    constraint pk_vwgcfld_infos
        primary key (view_name, view_geometry, ordinal, column_name),
    constraint fk_vwgcfld_infos
        foreign key (view_name, view_geometry) references views_geometry_columns
            on delete cascade
);

CREATE TRIGGER vwgcfi_view_geometry_insert
    BEFORE INSERT ON 'views_geometry_columns_field_infos'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'insert on views_geometry_columns_field_infos violates constraint: view_geometry value must not contain a single quote')
    WHERE NEW.view_geometry LIKE ('%''%');
    SELECT RAISE(ABORT,'insert on views_geometry_columns_field_infos violates constraint:
view_geometry value must not contain a double quote')
    WHERE NEW.view_geometry LIKE ('%"%');
    SELECT RAISE(ABORT,'insert on views_geometry_columns_field_infos violates constraint: view_geometry value must be lower case')
    WHERE NEW.view_geometry <> lower(NEW.view_geometry);
END;

CREATE TRIGGER vwgcfi_view_geometry_update
    BEFORE UPDATE OF 'view_geometry' ON 'views_geometry_columns_field_infos'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'update on views_geometry_columns_field_infos violates constraint: view_geometry value must not contain a single quote')
    WHERE NEW.view_geometry LIKE ('%''%');
    SELECT RAISE(ABORT,'update on views_geometry_columns_field_infos violates constraint:
view_geometry value must not contain a double quote')
    WHERE NEW.view_geometry LIKE ('%"%');
    SELECT RAISE(ABORT,'update on views_geometry_columns_field_infos violates constraint: view_geometry value must be lower case')
    WHERE NEW.view_geometry <> lower(NEW.view_geometry);
END;

CREATE TRIGGER vwgcfi_view_name_insert
    BEFORE INSERT ON 'views_geometry_columns_field_infos'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'insert on views_geometry_columns_field_infos violates constraint: view_name value must not contain a single quote')
    WHERE NEW.view_name LIKE ('%''%');
    SELECT RAISE(ABORT,'insert on views_geometry_columns_field_infos violates constraint: view_name value must not contain a double quote')
    WHERE NEW.view_name LIKE ('%"%');
    SELECT RAISE(ABORT,'insert on views_geometry_columns_field_infos violates constraint:
view_name value must be lower case')
    WHERE NEW.view_name <> lower(NEW.view_name);
END;

CREATE TRIGGER vwgcfi_view_name_update
    BEFORE UPDATE OF 'view_name' ON 'views_geometry_columns_field_infos'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'update on views_geometry_columns_field_infos violates constraint: view_name value must not contain a single quote')
    WHERE NEW.view_name LIKE ('%''%');
    SELECT RAISE(ABORT,'update on views_geometry_columns_field_infos violates constraint: view_name value must not contain a double quote')
    WHERE NEW.view_name LIKE ('%"%');
    SELECT RAISE(ABORT,'update on views_geometry_columns_field_infos violates constraint: view_name value must be lower case')
    WHERE NEW.view_name <> lower(NEW.view_name);
END;

create table views_geometry_columns_statistics
(
    view_name TEXT not null,
    view_geometry TEXT not null,
    last_verified TIMESTAMP,
    row_count INTEGER,
    extent_min_x DOUBLE,
    extent_min_y DOUBLE,
    extent_max_x DOUBLE,
    extent_max_y DOUBLE,
    constraint pk_vwgc_statistics
        primary key (view_name, view_geometry),
    constraint fk_vwgc_statistics
        foreign key (view_name, view_geometry) references views_geometry_columns
            on delete cascade
);

CREATE TRIGGER vwgcs_view_geometry_insert
    BEFORE INSERT ON 'views_geometry_columns_statistics'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'insert on views_geometry_columns_statistics violates constraint: view_geometry value must not contain a single quote')
    WHERE NEW.view_geometry LIKE ('%''%');
    SELECT RAISE(ABORT,'insert on views_geometry_columns_statistics violates constraint:
view_geometry value must not contain a double quote')
    WHERE NEW.view_geometry LIKE ('%"%');
    SELECT RAISE(ABORT,'insert on views_geometry_columns_statistics violates constraint: view_geometry value must be lower case')
    WHERE NEW.view_geometry <> lower(NEW.view_geometry);
END;

CREATE TRIGGER vwgcs_view_geometry_update
    BEFORE UPDATE OF 'view_geometry' ON 'views_geometry_columns_statistics'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'update on views_geometry_columns_statistics violates constraint: view_geometry value must not contain a single quote')
    WHERE NEW.view_geometry LIKE ('%''%');
    SELECT RAISE(ABORT,'update on views_geometry_columns_statistics violates constraint:
view_geometry value must not contain a double quote')
    WHERE NEW.view_geometry LIKE ('%"%');
    SELECT RAISE(ABORT,'update on views_geometry_columns_statistics violates constraint: view_geometry value must be lower case')
    WHERE NEW.view_geometry <> lower(NEW.view_geometry);
END;

CREATE TRIGGER vwgcs_view_name_insert
    BEFORE INSERT ON 'views_geometry_columns_statistics'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'insert on views_geometry_columns_statistics violates constraint: view_name value must not contain a single quote')
    WHERE NEW.view_name LIKE ('%''%');
    SELECT RAISE(ABORT,'insert on views_geometry_columns_statistics violates constraint: view_name value must not contain a double quote')
    WHERE NEW.view_name LIKE ('%"%');
    SELECT RAISE(ABORT,'insert on views_geometry_columns_statistics violates constraint:
view_name value must be lower case')
    WHERE NEW.view_name <> lower(NEW.view_name);
END;

CREATE TRIGGER vwgcs_view_name_update
    BEFORE UPDATE OF 'view_name' ON 'views_geometry_columns_statistics'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'update on views_geometry_columns_statistics violates constraint: view_name value must not contain a single quote')
    WHERE NEW.view_name LIKE ('%''%');
    SELECT RAISE(ABORT,'update on views_geometry_columns_statistics violates constraint: view_name value must not contain a double quote')
    WHERE NEW.view_name LIKE ('%"%');
    SELECT RAISE(ABORT,'update on views_geometry_columns_statistics violates constraint: view_name value must be lower case')
    WHERE NEW.view_name <> lower(NEW.view_name);
END;

create table virts_geometry_columns
(
    virt_name TEXT not null,
    virt_geometry TEXT not null,
    geometry_type INTEGER not null,
    coord_dimension INTEGER not null,
    srid INTEGER not null
        constraint fk_vgc_srid
            references spatial_ref_sys,
    constraint pk_geom_cols_virts
        primary key (virt_name, virt_geometry)
);

create index idx_virtssrid
    on virts_geometry_columns (srid);

CREATE TRIGGER vtgc_coord_dimension_insert
    BEFORE INSERT ON 'virts_geometry_columns'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'coord_dimension must be one of 2,3,4')
    WHERE NOT(NEW.coord_dimension IN (2,3,4));
END;

CREATE TRIGGER vtgc_coord_dimension_update
    BEFORE UPDATE OF 'coord_dimension' ON 'virts_geometry_columns'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'coord_dimension must be one of 2,3,4')
    WHERE NOT(NEW.coord_dimension IN (2,3,4));
END;

CREATE TRIGGER vtgc_geometry_type_insert
    BEFORE INSERT ON 'virts_geometry_columns'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'geometry_type must be one of 0,1,2,3,4,5,6,7,1000,1001,1002,1003,1004,1005,1006,1007,2000,2001,2002,2003,2004,2005,2006,2007,3000,3001,3002,3003,3004,3005,3006,3007')
    WHERE NOT(NEW.geometry_type IN (0,1,2,3,4,5,6,7,1000,1001,1002,1003,1004,1005,1006,1007,2000,2001,2002,2003,2004,2005,2006,2007,3000,3001,3002,3003,3004,3005,3006,3007));
END;

CREATE TRIGGER vtgc_geometry_type_update
    BEFORE UPDATE OF 'geometry_type' ON 'virts_geometry_columns'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'geometry_type must be one of 0,1,2,3,4,5,6,7,1000,1001,1002,1003,1004,1005,1006,1007,2000,2001,2002,2003,2004,2005,2006,2007,3000,3001,3002,3003,3004,3005,3006,3007')
    WHERE NOT(NEW.geometry_type IN (0,1,2,3,4,5,6,7,1000,1001,1002,1003,1004,1005,1006,1007,2000,2001,2002,2003,2004,2005,2006,2007,3000,3001,3002,3003,3004,3005,3006,3007));
END;

CREATE TRIGGER vtgc_virt_geometry_insert
    BEFORE INSERT ON 'virts_geometry_columns'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'insert on virts_geometry_columns violates constraint: virt_geometry value must not contain a single quote')
    WHERE NEW.virt_geometry LIKE ('%''%');
    SELECT RAISE(ABORT,'insert on virts_geometry_columns violates constraint:
virt_geometry value must not contain a double quote')
    WHERE NEW.virt_geometry LIKE ('%"%');
    SELECT RAISE(ABORT,'insert on virts_geometry_columns violates constraint: virt_geometry value must be lower case')
    WHERE NEW.virt_geometry <> lower(NEW.virt_geometry);
END;

CREATE TRIGGER vtgc_virt_geometry_update
    BEFORE UPDATE OF 'virt_geometry' ON 'virts_geometry_columns'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'update on virts_geometry_columns violates constraint: virt_geometry value must not contain a single quote')
    WHERE NEW.virt_geometry LIKE ('%''%');
    SELECT RAISE(ABORT,'update on virts_geometry_columns violates constraint:
virt_geometry value must not contain a double quote')
    WHERE NEW.virt_geometry LIKE ('%"%');
    SELECT RAISE(ABORT,'update on virts_geometry_columns violates constraint: virt_geometry value must be lower case')
    WHERE NEW.virt_geometry <> lower(NEW.virt_geometry);
END;

CREATE TRIGGER vtgc_virt_name_insert
    BEFORE INSERT ON 'virts_geometry_columns'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'insert on virts_geometry_columns violates constraint: virt_name value must not contain a single quote')
    WHERE NEW.virt_name LIKE ('%''%');
    SELECT RAISE(ABORT,'insert on virts_geometry_columns violates constraint: virt_name value must not contain a double quote')
    WHERE NEW.virt_name LIKE ('%"%');
    SELECT RAISE(ABORT,'insert on virts_geometry_columns violates constraint:
virt_name value must be lower case')
    WHERE NEW.virt_name <> lower(NEW.virt_name);
END;

CREATE TRIGGER vtgc_virt_name_update
    BEFORE UPDATE OF 'virt_name' ON 'virts_geometry_columns'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'update on virts_geometry_columns violates constraint: virt_name value must not contain a single quote')
    WHERE NEW.virt_name LIKE ('%''%');
    SELECT RAISE(ABORT,'update on virts_geometry_columns violates constraint: virt_name value must not contain a double quote')
    WHERE NEW.virt_name LIKE ('%"%');
    SELECT RAISE(ABORT,'update on virts_geometry_columns violates constraint: virt_name value must be lower case')
    WHERE NEW.virt_name <> lower(NEW.virt_name);
END;

create table virts_geometry_columns_auth
(
    virt_name TEXT not null,
    virt_geometry TEXT not null,
    hidden INTEGER not null,
    constraint pk_vrtgc_auth
        primary key (virt_name, virt_geometry),
    constraint fk_vrtgc_auth
        foreign key (virt_name, virt_geometry) references virts_geometry_columns
            on delete cascade,
    constraint ck_vrtgc_hidden
        check (hidden IN (0,1))
);

CREATE TRIGGER vtgcau_virt_geometry_insert
    BEFORE INSERT ON 'virts_geometry_columns_auth'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'insert on virts_geometry_columns_auth violates constraint: virt_geometry value must not contain a single quote')
    WHERE NEW.virt_geometry LIKE ('%''%');
    SELECT RAISE(ABORT,'insert on virts_geometry_columns_auth violates constraint:
virt_geometry value must not contain a double quote')
    WHERE NEW.virt_geometry LIKE ('%"%');
    SELECT RAISE(ABORT,'insert on virts_geometry_columns_auth violates constraint: virt_geometry value must be lower case')
    WHERE NEW.virt_geometry <> lower(NEW.virt_geometry);
END;

CREATE TRIGGER vtgcau_virt_geometry_update
    BEFORE UPDATE OF 'virt_geometry' ON 'virts_geometry_columns_auth'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'update on virts_geometry_columns_auth violates constraint: virt_geometry value must not contain a single quote')
    WHERE NEW.virt_geometry LIKE ('%''%');
    SELECT RAISE(ABORT,'update on virts_geometry_columns_auth violates constraint:
virt_geometry value must not contain a double quote')
    WHERE NEW.virt_geometry LIKE ('%"%');
    SELECT RAISE(ABORT,'update on virts_geometry_columns_auth violates constraint: virt_geometry value must be lower case')
    WHERE NEW.virt_geometry <> lower(NEW.virt_geometry);
END;

CREATE TRIGGER vtgcau_virt_name_insert
    BEFORE INSERT ON 'virts_geometry_columns_auth'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'insert on virts_geometry_columns_auth violates constraint: virt_name value must not contain a single quote')
    WHERE NEW.virt_name LIKE ('%''%');
    SELECT RAISE(ABORT,'insert on virts_geometry_columns_auth violates constraint: virt_name value must not contain a double quote')
    WHERE NEW.virt_name LIKE ('%"%');
    SELECT RAISE(ABORT,'insert on virts_geometry_columns_auth violates constraint:
virt_name value must be lower case')
    WHERE NEW.virt_name <> lower(NEW.virt_name);
END;

CREATE TRIGGER vtgcau_virt_name_update
    BEFORE UPDATE OF 'virt_name' ON 'virts_geometry_columns_auth'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'update on virts_geometry_columns_auth violates constraint: virt_name value must not contain a single quote')
    WHERE NEW.virt_name LIKE ('%''%');
    SELECT RAISE(ABORT,'update on virts_geometry_columns_auth violates constraint: virt_name value must not contain a double quote')
    WHERE NEW.virt_name LIKE ('%"%');
    SELECT RAISE(ABORT,'update on virts_geometry_columns_auth violates constraint: virt_name value must be lower case')
    WHERE NEW.virt_name <> lower(NEW.virt_name);
END;

create table virts_geometry_columns_field_infos
(
    virt_name TEXT not null,
    virt_geometry TEXT not null,
    ordinal INTEGER not null,
    column_name TEXT not null,
    null_values INTEGER not null,
    integer_values INTEGER not null,
    double_values INTEGER not null,
    text_values INTEGER not null,
    blob_values INTEGER not null,
    max_size INTEGER,
    integer_min INTEGER,
    integer_max INTEGER,
    double_min DOUBLE,
    double_max DOUBLE,
    constraint pk_vrtgcfld_infos
        primary key (virt_name, virt_geometry, ordinal, column_name),
    constraint fk_vrtgcfld_infos
        foreign key (virt_name, virt_geometry) references virts_geometry_columns
            on delete cascade
);

CREATE TRIGGER vtgcfi_virt_geometry_insert
    BEFORE INSERT ON 'virts_geometry_columns_field_infos'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'insert on virts_geometry_columns_field_infos violates constraint: virt_geometry value must not contain a single quote')
    WHERE NEW.virt_geometry LIKE ('%''%');
    SELECT RAISE(ABORT,'insert on virts_geometry_columns_field_infos violates constraint:
virt_geometry value must not contain a double quote')
    WHERE NEW.virt_geometry LIKE ('%"%');
    SELECT RAISE(ABORT,'insert on virts_geometry_columns_field_infos violates constraint: virt_geometry value must be lower case')
    WHERE NEW.virt_geometry <> lower(NEW.virt_geometry);
END;

CREATE TRIGGER vtgcfi_virt_geometry_update
    BEFORE UPDATE OF 'virt_geometry' ON 'virts_geometry_columns_field_infos'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'update on virts_geometry_columns_field_infos violates constraint: virt_geometry value must not contain a single quote')
    WHERE NEW.virt_geometry LIKE ('%''%');
    SELECT RAISE(ABORT,'update on virts_geometry_columns_field_infos violates constraint:
virt_geometry value must not contain a double quote')
    WHERE NEW.virt_geometry LIKE ('%"%');
    SELECT RAISE(ABORT,'update on virts_geometry_columns_field_infos violates constraint: virt_geometry value must be lower case')
    WHERE NEW.virt_geometry <> lower(NEW.virt_geometry);
END;

CREATE TRIGGER vtgcfi_virt_name_insert
    BEFORE INSERT ON 'virts_geometry_columns_field_infos'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'insert on virts_geometry_columns_field_infos violates constraint: virt_name value must not contain a single quote')
    WHERE NEW.virt_name LIKE ('%''%');
    SELECT RAISE(ABORT,'insert on virts_geometry_columns_field_infos violates constraint: virt_name value must not contain a double quote')
    WHERE NEW.virt_name LIKE ('%"%');
    SELECT RAISE(ABORT,'insert on virts_geometry_columns_field_infos violates constraint:
virt_name value must be lower case')
    WHERE NEW.virt_name <> lower(NEW.virt_name);
END;

CREATE TRIGGER vtgcfi_virt_name_update
    BEFORE UPDATE OF 'virt_name' ON 'virts_geometry_columns_field_infos'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'update on virts_geometry_columns_field_infos violates constraint: virt_name value must not contain a single quote')
    WHERE NEW.virt_name LIKE ('%''%');
    SELECT RAISE(ABORT,'update on virts_geometry_columns_field_infos violates constraint: virt_name value must not contain a double quote')
    WHERE NEW.virt_name LIKE ('%"%');
    SELECT RAISE(ABORT,'update on virts_geometry_columns_field_infos violates constraint: virt_name value must be lower case')
    WHERE NEW.virt_name <> lower(NEW.virt_name);
END;

create table virts_geometry_columns_statistics
(
    virt_name TEXT not null,
    virt_geometry TEXT not null,
    last_verified TIMESTAMP,
    row_count INTEGER,
    extent_min_x DOUBLE,
    extent_min_y DOUBLE,
    extent_max_x DOUBLE,
    extent_max_y DOUBLE,
    constraint pk_vrtgc_statistics
        primary key (virt_name, virt_geometry),
    constraint fk_vrtgc_statistics
        foreign key (virt_name, virt_geometry) references virts_geometry_columns
            on delete cascade
);

CREATE TRIGGER vtgcs_virt_geometry_insert
    BEFORE INSERT ON 'virts_geometry_columns_statistics'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'insert on virts_geometry_columns_statistics violates constraint: virt_geometry value must not contain a single quote')
    WHERE NEW.virt_geometry LIKE ('%''%');
    SELECT RAISE(ABORT,'insert on virts_geometry_columns_statistics violates constraint:
virt_geometry value must not contain a double quote')
    WHERE NEW.virt_geometry LIKE ('%"%');
    SELECT RAISE(ABORT,'insert on virts_geometry_columns_statistics violates constraint: virt_geometry value must be lower case')
    WHERE NEW.virt_geometry <> lower(NEW.virt_geometry);
END;

CREATE TRIGGER vtgcs_virt_geometry_update
    BEFORE UPDATE OF 'virt_geometry' ON 'virts_geometry_columns_statistics'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'update on virts_geometry_columns_statistics violates constraint: virt_geometry value must not contain a single quote')
    WHERE NEW.virt_geometry LIKE ('%''%');
    SELECT RAISE(ABORT,'update on virts_geometry_columns_statistics violates constraint:
virt_geometry value must not contain a double quote')
    WHERE NEW.virt_geometry LIKE ('%"%');
    SELECT RAISE(ABORT,'update on virts_geometry_columns_statistics violates constraint: virt_geometry value must be lower case')
    WHERE NEW.virt_geometry <> lower(NEW.virt_geometry);
END;

CREATE TRIGGER vtgcs_virt_name_insert
    BEFORE INSERT ON 'virts_geometry_columns_statistics'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'insert on virts_geometry_columns_statistics violates constraint: virt_name value must not contain a single quote')
    WHERE NEW.virt_name LIKE ('%''%');
    SELECT RAISE(ABORT,'insert on virts_geometry_columns_statistics violates constraint: virt_name value must not contain a double quote')
    WHERE NEW.virt_name LIKE ('%"%');
    SELECT RAISE(ABORT,'insert on virts_geometry_columns_statistics violates constraint:
virt_name value must be lower case')
    WHERE NEW.virt_name <> lower(NEW.virt_name);
END;

CREATE TRIGGER vtgcs_virt_name_update
    BEFORE UPDATE OF 'virt_name' ON 'virts_geometry_columns_statistics'
    FOR EACH ROW BEGIN
    SELECT RAISE(ABORT,'update on virts_geometry_columns_statistics violates constraint: virt_name value must not contain a single quote')
    WHERE NEW.virt_name LIKE ('%''%');
    SELECT RAISE(ABORT,'update on virts_geometry_columns_statistics violates constraint: virt_name value must not contain a double quote')
    WHERE NEW.virt_name LIKE ('%"%');
    SELECT RAISE(ABORT,'update on virts_geometry_columns_statistics violates constraint: virt_name value must be lower case')
    WHERE NEW.virt_name <> lower(NEW.virt_name);
END;

CREATE VIEW geom_cols_ref_sys AS
SELECT f_table_name, f_geometry_column, geometry_type,
       coord_dimension, spatial_ref_sys.srid AS srid,
       auth_name, auth_srid, ref_sys_name, proj4text, srtext
FROM geometry_columns, spatial_ref_sys
WHERE geometry_columns.srid = spatial_ref_sys.srid;

CREATE VIEW spatial_ref_sys_all AS
SELECT a.srid AS srid, a.auth_name AS auth_name, a.auth_srid AS auth_srid, a.ref_sys_name AS ref_sys_name,
       b.is_geographic AS is_geographic, b.has_flipped_axes AS has_flipped_axes, b.spheroid AS spheroid, b.prime_meridian AS prime_meridian, b.datum AS datum, b.projection AS projection, b.unit AS unit,
       b.axis_1_name AS axis_1_name, b.axis_1_orientation AS axis_1_orientation,
       b.axis_2_name AS axis_2_name, b.axis_2_orientation AS axis_2_orientation,
       a.proj4text AS proj4text, a.srtext AS srtext
FROM spatial_ref_sys AS a
         LEFT JOIN spatial_ref_sys_aux AS b ON (a.srid = b.srid);

CREATE VIEW vector_layers AS
SELECT 'SpatialTable' AS layer_type, f_table_name AS table_name, f_geometry_column AS geometry_column, geometry_type AS geometry_type, coord_dimension AS coord_dimension, srid AS srid, spatial_index_enabled AS spatial_index_enabled
FROM geometry_columns
UNION
SELECT 'SpatialView' AS layer_type, a.view_name AS table_name, a.view_geometry AS geometry_column, b.geometry_type AS geometry_type, b.coord_dimension AS coord_dimension, b.srid AS srid, b.spatial_index_enabled AS spatial_index_enabled
FROM views_geometry_columns AS a
         LEFT JOIN geometry_columns AS b ON (Upper(a.f_table_name) = Upper(b.f_table_name) AND Upper(a.f_geometry_column) = Upper(b.f_geometry_column))
UNION
SELECT 'VirtualShape' AS layer_type, virt_name AS table_name, virt_geometry AS geometry_column, geometry_type AS geometry_type, coord_dimension AS coord_dimension, srid AS srid, 0 AS spatial_index_enabled
FROM virts_geometry_columns;

CREATE VIEW vector_layers_auth AS
SELECT 'SpatialTable' AS layer_type, f_table_name AS table_name, f_geometry_column AS geometry_column, read_only AS read_only, hidden AS hidden
FROM geometry_columns_auth
UNION
SELECT 'SpatialView' AS layer_type, a.view_name AS table_name, a.view_geometry AS geometry_column, b.read_only AS read_only, a.hidden AS hidden
FROM views_geometry_columns_auth AS a
         JOIN views_geometry_columns AS b ON (Upper(a.view_name) = Upper(b.view_name) AND Upper(a.view_geometry) = Upper(b.view_geometry))
UNION
SELECT 'VirtualShape' AS layer_type, virt_name AS table_name, virt_geometry AS geometry_column, 1 AS read_only, hidden AS hidden
FROM virts_geometry_columns_auth;

CREATE VIEW vector_layers_field_infos AS
SELECT 'SpatialTable' AS layer_type, f_table_name AS table_name, f_geometry_column AS geometry_column, ordinal AS ordinal, column_name AS column_name, null_values AS null_values, integer_values AS integer_values, double_values AS double_values, text_values AS text_values, blob_values AS blob_values, max_size AS max_size, integer_min AS integer_min, integer_max AS integer_max, double_min AS double_min, double_max double_max
FROM geometry_columns_field_infos
UNION
SELECT 'SpatialView' AS layer_type, view_name AS table_name, view_geometry AS geometry_column, ordinal AS ordinal, column_name AS column_name, null_values AS null_values, integer_values AS integer_values, double_values AS double_values, text_values AS text_values, blob_values AS blob_values, max_size AS max_size, integer_min AS integer_min, integer_max AS integer_max, double_min AS double_min, double_max double_max
FROM views_geometry_columns_field_infos
UNION
SELECT 'VirtualShape' AS layer_type, virt_name AS table_name, virt_geometry AS geometry_column, ordinal AS ordinal, column_name AS column_name, null_values AS null_values, integer_values AS integer_values, double_values AS double_values, text_values AS text_values, blob_values AS blob_values, max_size AS max_size, integer_min AS integer_min, integer_max AS integer_max, double_min AS double_min, double_max double_max
FROM virts_geometry_columns_field_infos;

CREATE VIEW vector_layers_statistics AS
SELECT 'SpatialTable' AS layer_type, f_table_name AS table_name, f_geometry_column AS geometry_column, last_verified AS last_verified, row_count AS row_count, extent_min_x AS extent_min_x, extent_min_y AS extent_min_y, extent_max_x AS extent_max_x, extent_max_y AS extent_max_y
FROM geometry_columns_statistics
UNION
SELECT 'SpatialView' AS layer_type, view_name AS table_name, view_geometry AS geometry_column, last_verified AS last_verified, row_count AS row_count, extent_min_x AS extent_min_x, extent_min_y AS extent_min_y, extent_max_x AS extent_max_x, extent_max_y AS extent_max_y
FROM views_geometry_columns_statistics
UNION
SELECT 'VirtualShape' AS layer_type, virt_name AS table_name, virt_geometry AS geometry_column, last_verified AS last_verified, row_count AS row_count, extent_min_x AS extent_min_x, extent_min_y AS extent_min_y, extent_max_x AS extent_max_x, extent_max_y AS extent_max_y
FROM virts_geometry_columns_statistics;

create virtual table ElementaryGeometries using VirtualElementary(
);

create virtual table SpatialIndex using VirtualSpatialIndex(
);

create virtual table idx_servers_loc using rtree(
                                                    pkid,
                                                    xmin,
                                                    xmax,
                                                    ymin,
                                                    ymax
);

