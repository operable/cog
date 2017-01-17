--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.1
-- Dumped by pg_dump version 9.6.1

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


SET search_path = public, pg_catalog;

--
-- Name: disable_bundle_version(uuid, integer[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION disable_bundle_version(p_bundle_id uuid, p_version integer[]) RETURNS void
    LANGUAGE sql
    AS $$
  DELETE FROM enabled_bundle_versions
  WHERE bundle_id = p_bundle_id
    AND version = p_version;;
$$;


--
-- Name: enable_bundle_version(uuid, integer[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION enable_bundle_version(p_bundle_id uuid, p_version integer[]) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  INSERT INTO enabled_bundle_versions(bundle_id, version)
  VALUES(p_bundle_id, p_version);
EXCEPTION
  WHEN unique_violation THEN
    DELETE FROM enabled_bundle_versions
    WHERE bundle_id = p_bundle_id;

    INSERT INTO enabled_bundle_versions(bundle_id, version)
    VALUES(p_bundle_id, p_version);
END;
$$;


--
-- Name: fetch_user_permissions(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION fetch_user_permissions(p_user uuid) RETURNS TABLE(id uuid, name text)
    LANGUAGE plpgsql STABLE STRICT
    AS $$
 BEGIN

 RETURN QUERY WITH

   -- Walk the tree of group memberships and find
   -- all the groups the user is a direct and
   -- indirect member of.
   all_groups as (
   SELECT group_id
     FROM groups_for_user(p_user)
   ),
   all_permissions as (

   -- Retrieve all permissions granted to the list
   -- groups returned from all_groups
   SELECT gp.permission_id
     FROM group_permissions as gp
     JOIN all_groups as ag
       ON gp.group_id = ag.group_id
   UNION DISTINCT

   -- Retrieve all permissions granted to the user
   -- via roles
   SELECT rp.permission_id
     FROM role_permissions as rp
     JOIN user_roles as ur
       ON rp.role_id = ur.role_id
     WHERE ur.user_id = p_user
   UNION DISTINCT

   -- Retrieve all permissions granted to the groups
   -- via roles
   SELECT rp.permission_id
     FROM role_permissions as rp
     JOIN group_roles as gr
       ON rp.role_id = gr.role_id
     JOIN all_groups AS ag
       ON gr.group_id = ag.group_id
   UNION DISTINCT

   -- Retrieve all permissions granted directly to the user
   SELECT up.permission_id
     FROM user_permissions as up
    WHERE up.user_id = p_user
   )

 -- Join the permission ids returned by the CTE against
 -- the permissions and namespaces tables to produce
 -- the final result
 SELECT p.id, b.name||':'||p.name as name
   FROM permissions as p, bundles as b, all_permissions as ap
  WHERE ap.permission_id = p.id and p.bundle_id = b.id;
 END;
 $$;


--
-- Name: forbid_group_cycles(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION forbid_group_cycles() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  cycle_root BOOLEAN DEFAULT FALSE;
BEGIN
  SELECT INTO cycle_root (
      WITH RECURSIVE
          parents(id) AS (
              -- parent(s) of the current child group
              SELECT group_id
              FROM group_group_membership
              WHERE member_id = NEW.member_id

              UNION

              -- grandparents and other ancestors
              SELECT ggm.group_id
              FROM group_group_membership AS ggm
              JOIN parents AS p ON ggm.member_id = p.id
          )
      SELECT TRUE
      FROM parents
      WHERE id = NEW.member_id
  );

  IF cycle_root THEN
    RAISE EXCEPTION 'group cycles are forbidden';
  END IF;
  RETURN NULL;
END;
$$;


--
-- Name: groups_for_user(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION groups_for_user(uuid) RETURNS TABLE(group_id uuid)
    LANGUAGE sql STABLE STRICT
    AS $_$
WITH RECURSIVE
  in_groups(id) AS (
    -- direct group membership
    SELECT group_id
    FROM user_group_membership
    WHERE member_id = $1

    UNION

    -- indirect group membership; find parent groups of all groups
    -- the user is a direct member of, recursively
    SELECT ggm.group_id
    FROM group_group_membership AS ggm
    JOIN in_groups ON in_groups.id = ggm.member_id
)
SELECT id from in_groups;
$_$;


--
-- Name: groups_with_permission(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION groups_with_permission(p_permission uuid) RETURNS SETOF uuid
    LANGUAGE sql STABLE STRICT
    AS $$
  WITH RECURSIVE
  direct_grants AS (
    SELECT group_id
    FROM group_permissions
    WHERE permission_id = p_permission
  ),
  role_grants AS (
    SELECT gr.group_id
    FROM group_roles AS gr
    JOIN role_permissions AS rp
      USING (role_id)
    WHERE rp.permission_id = p_permission
  ),
  in_groups AS (
    SELECT group_id FROM direct_grants
    UNION
    SELECT group_id FROM role_grants
    UNION
    -- find all groups that are members of that group, etc.
    SELECT ggm.member_id
    FROM group_group_membership AS ggm
    JOIN in_groups AS ig
      USING (group_id)
  )
  SELECT group_id
   FROM in_groups;
$$;


--
-- Name: protect_admin_group(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION protect_admin_group() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF OLD.NAME = 'cog-admin' THEN
    RAISE EXCEPTION 'cannot modify admin group';
  END IF;
  RETURN NULL;
END;
$$;


--
-- Name: protect_admin_group_membership(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION protect_admin_group_membership() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  admin_member_id     uuid;
  cog_admin_group_id  uuid;
BEGIN
  SELECT id INTO admin_member_id
  FROM users
  WHERE username = 'admin';

  SELECT id INTO cog_admin_group_id
  FROM groups
  WHERE name = 'cog-admin';

  IF OLD.member_id = admin_member_id AND OLD.group_id = cog_admin_group_id THEN
    RAISE EXCEPTION 'cannot remove admin user from cog-admin group';
  END IF;
  RETURN NULL;
END;
$$;


--
-- Name: protect_admin_role(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION protect_admin_role() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF OLD.NAME = 'cog-admin' THEN
    RAISE EXCEPTION 'cannot modify admin role';
  END IF;
  RETURN NULL;
END;
$$;


--
-- Name: protect_admin_role_permissions(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION protect_admin_role_permissions() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  role TEXT;
  bundle TEXT;
BEGIN
  SELECT roles.name INTO role FROM roles WHERE roles.id=OLD.role_id;

  SELECT bundles.name
    INTO bundle
    FROM bundles, permissions
   WHERE bundles.id=permissions.bundle_id
     AND permissions.id=OLD.permission_id;

  IF role = 'cog-admin' AND bundle = 'operable' THEN
    RAISE EXCEPTION 'cannot remove embedded permissions from admin role';
  END IF;
  RETURN NULL;
END;
$$;


--
-- Name: protect_embedded_bundle(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION protect_embedded_bundle() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF OLD.NAME = 'operable' THEN
    RAISE EXCEPTION 'cannot modify embedded bundle';
  END IF;
  RETURN NULL;
END;
$$;


--
-- Name: user_has_permission(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION user_has_permission(p_user uuid, p_perm uuid) RETURNS boolean
    LANGUAGE plpgsql STABLE STRICT
    AS $$
DECLARE
has_result uuid;
BEGIN
-- Check to see if the actor has the permission directly
SELECT up.permission_id FROM user_permissions AS up
WHERE up.user_id = p_user
  AND up.permission_id = p_perm
 INTO has_result;

-- If that returned anything, we're done
IF has_result IS NOT NULL THEN
 RETURN TRUE;
END IF;

-- The user might have a role, though; check that!
SELECT rp.permission_id
 FROM role_permissions AS rp
 JOIN user_roles AS ur
   ON rp.role_id = ur.role_id
WHERE ur.user_id = p_user
  AND rp.permission_id = p_perm
 INTO has_result;

-- If that returned anything, we're done
IF has_result IS NOT NULL THEN
 RETURN TRUE;
END IF;

-- The permission wasn't granted directly to the user, we need
-- to check the groups the user is in
WITH all_groups AS (
 SELECT id FROM groups_for_user(p_user) AS g(id)
),
group_permissions AS (
 SELECT gp.permission_id
   FROM group_permissions AS gp
   JOIN all_groups AS gfu
     ON gp.group_id = gfu.id
  WHERE gp.permission_id = p_perm
),
group_role_permissions AS (
 SELECT rp.permission_id
   FROM role_permissions AS rp
   JOIN group_roles AS gr
     ON rp.role_id = gr.role_id
   JOIN all_groups AS ag
     ON gr.group_id = ag.id -- group_id, natural joins
  WHERE rp.permission_id = p_perm
),
everything AS (
 SELECT permission_id FROM group_permissions
 UNION DISTINCT
 SELECT permission_id FROM group_role_permissions
)
SELECT permission_id
FROM everything
INTO has_result;

-- If anything was found, we're done
IF has_result IS NOT NULL THEN
 RETURN TRUE;
END IF;

-- The user doesn't have the permission
RETURN FALSE;

END;
$$;


--
-- Name: users_with_permission(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION users_with_permission(p_permission uuid) RETURNS SETOF uuid
    LANGUAGE sql STABLE STRICT
    AS $$
  WITH direct_grants AS (
    SELECT up.user_id
    FROM user_permissions AS up
    WHERE up.permission_id = p_permission
  ),
  role_grants AS (
    SELECT ur.user_id
    FROM user_roles AS ur
    JOIN role_permissions AS rp
      USING(role_id)
    WHERE rp.permission_id = p_permission
  ),
  all_groups AS (
    SELECT group_id
    FROM groups_with_permission(p_permission) AS g(group_id)
  ),
  group_grants AS (
    SELECT ugm.member_id AS user_id
    FROM user_group_membership AS ugm
    JOIN all_groups AS ag
      USING(group_id)
  )
  SELECT user_id FROM direct_grants
  UNION
  SELECT user_id FROM role_grants
  UNION
  SELECT user_id FROM group_grants
  ;
$$;


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: bundle_dynamic_configs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE bundle_dynamic_configs (
    bundle_id uuid NOT NULL,
    config jsonb NOT NULL,
    hash text NOT NULL,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    layer text NOT NULL,
    name text NOT NULL,
    CONSTRAINT base_name_must_be_config CHECK (
CASE
    WHEN (layer = 'base'::text) THEN (name = 'config'::text)
    ELSE NULL::boolean
END)
);


--
-- Name: bundle_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE bundle_versions (
    id uuid NOT NULL,
    bundle_id uuid NOT NULL,
    version integer[] DEFAULT ARRAY[0, 0, 0] NOT NULL,
    config_file json NOT NULL,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    description text,
    long_description text,
    author character varying(255),
    homepage character varying(255)
);


--
-- Name: bundles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE bundles (
    id uuid NOT NULL,
    name text NOT NULL,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: chat_handles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE chat_handles (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    provider_id integer NOT NULL,
    handle text NOT NULL,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    chat_provider_user_id text NOT NULL
);


--
-- Name: chat_providers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE chat_providers (
    id integer NOT NULL,
    name text NOT NULL,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    data jsonb
);


--
-- Name: chat_providers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE chat_providers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chat_providers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE chat_providers_id_seq OWNED BY chat_providers.id;


--
-- Name: command_option_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE command_option_types (
    id uuid NOT NULL,
    name text NOT NULL
);


--
-- Name: command_options; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE command_options (
    id uuid NOT NULL,
    command_version_id uuid NOT NULL,
    option_type_id uuid NOT NULL,
    name text NOT NULL,
    description text,
    required boolean NOT NULL,
    short_flag text,
    long_flag text,
    CONSTRAINT flags_check CHECK (((long_flag IS NOT NULL) OR (short_flag IS NOT NULL)))
);


--
-- Name: command_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE command_versions (
    id uuid NOT NULL,
    bundle_version_id uuid NOT NULL,
    command_id uuid NOT NULL,
    documentation text,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    description text,
    long_description text,
    examples text,
    notes text,
    arguments character varying(255),
    output json DEFAULT '{}'::json NOT NULL
);


--
-- Name: commands; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE commands (
    id uuid NOT NULL,
    bundle_id uuid NOT NULL,
    name text NOT NULL,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: enabled_bundle_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE enabled_bundle_versions (
    bundle_id uuid NOT NULL,
    version integer[] NOT NULL
);


--
-- Name: enabled_bundle_version_view; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW enabled_bundle_version_view AS
 SELECT bv.bundle_id,
    bv.id AS bundle_version_id
   FROM (enabled_bundle_versions e
     JOIN bundle_versions bv ON (((e.bundle_id = bv.bundle_id) AND (e.version = bv.version))));


--
-- Name: group_group_membership; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE group_group_membership (
    member_id uuid NOT NULL,
    group_id uuid NOT NULL
);


--
-- Name: group_permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE group_permissions (
    group_id uuid NOT NULL,
    permission_id uuid NOT NULL
);


--
-- Name: group_roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE group_roles (
    group_id uuid NOT NULL,
    role_id uuid NOT NULL
);


--
-- Name: groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE groups (
    id uuid NOT NULL,
    name text NOT NULL
);


--
-- Name: password_resets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE password_resets (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: permission_bundle_version; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE permission_bundle_version (
    permission_id uuid NOT NULL,
    bundle_version_id uuid NOT NULL
);


--
-- Name: permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE permissions (
    id uuid NOT NULL,
    bundle_id uuid NOT NULL,
    name text NOT NULL,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: relay_group_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE relay_group_assignments (
    bundle_id uuid NOT NULL,
    group_id uuid NOT NULL
);


--
-- Name: relay_group_memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE relay_group_memberships (
    relay_id uuid NOT NULL,
    group_id uuid NOT NULL
);


--
-- Name: relay_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE relay_groups (
    id uuid NOT NULL,
    name text NOT NULL,
    "desc" text,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: relays; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE relays (
    id uuid NOT NULL,
    name text NOT NULL,
    token_digest text NOT NULL,
    enabled boolean NOT NULL,
    description text,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: role_permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE role_permissions (
    role_id uuid NOT NULL,
    permission_id uuid NOT NULL
);


--
-- Name: roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE roles (
    id uuid NOT NULL,
    name text NOT NULL
);


--
-- Name: rule_bundle_version; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE rule_bundle_version (
    rule_id uuid NOT NULL,
    bundle_version_id uuid NOT NULL
);


--
-- Name: rule_permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE rule_permissions (
    rule_id uuid NOT NULL,
    permission_id uuid NOT NULL
);


--
-- Name: rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE rules (
    id uuid NOT NULL,
    command_id uuid NOT NULL,
    parse_tree jsonb NOT NULL,
    score integer NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp without time zone
);


--
-- Name: site_command_aliases; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE site_command_aliases (
    id uuid NOT NULL,
    name character varying(255) NOT NULL,
    pipeline text NOT NULL,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: templates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE templates (
    id uuid NOT NULL,
    bundle_version_id uuid,
    adapter text NOT NULL,
    name text NOT NULL,
    source text NOT NULL,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE tokens (
    id uuid NOT NULL,
    user_id uuid,
    value text NOT NULL,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: triggers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE triggers (
    id uuid NOT NULL,
    name text NOT NULL,
    pipeline text NOT NULL,
    as_user text,
    timeout_sec integer DEFAULT 30 NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    description text,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: user_command_aliases; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE user_command_aliases (
    id uuid NOT NULL,
    name character varying(255) NOT NULL,
    user_id uuid NOT NULL,
    pipeline text NOT NULL,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: user_group_membership; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE user_group_membership (
    member_id uuid NOT NULL,
    group_id uuid NOT NULL
);


--
-- Name: user_permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE user_permissions (
    user_id uuid NOT NULL,
    permission_id uuid NOT NULL
);


--
-- Name: user_roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE user_roles (
    user_id uuid NOT NULL,
    role_id uuid NOT NULL
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE users (
    id uuid NOT NULL,
    first_name text,
    last_name text,
    email_address text NOT NULL,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    password_digest text,
    username text NOT NULL
);


--
-- Name: chat_providers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY chat_providers ALTER COLUMN id SET DEFAULT nextval('chat_providers_id_seq'::regclass);


--
-- Name: bundle_versions bundle_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY bundle_versions
    ADD CONSTRAINT bundle_versions_pkey PRIMARY KEY (id);


--
-- Name: bundles bundles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY bundles
    ADD CONSTRAINT bundles_pkey PRIMARY KEY (id);


--
-- Name: chat_handles chat_handles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY chat_handles
    ADD CONSTRAINT chat_handles_pkey PRIMARY KEY (id);


--
-- Name: chat_providers chat_providers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY chat_providers
    ADD CONSTRAINT chat_providers_pkey PRIMARY KEY (id);


--
-- Name: command_option_types command_option_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY command_option_types
    ADD CONSTRAINT command_option_types_pkey PRIMARY KEY (id);


--
-- Name: command_options command_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY command_options
    ADD CONSTRAINT command_options_pkey PRIMARY KEY (id);


--
-- Name: command_versions command_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY command_versions
    ADD CONSTRAINT command_versions_pkey PRIMARY KEY (id);


--
-- Name: commands commands_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY commands
    ADD CONSTRAINT commands_pkey PRIMARY KEY (id);


--
-- Name: enabled_bundle_versions enabled_bundle_versions_bundle_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY enabled_bundle_versions
    ADD CONSTRAINT enabled_bundle_versions_bundle_id_key UNIQUE (bundle_id);


--
-- Name: enabled_bundle_versions enabled_bundle_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY enabled_bundle_versions
    ADD CONSTRAINT enabled_bundle_versions_pkey PRIMARY KEY (bundle_id, version);


--
-- Name: groups groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY groups
    ADD CONSTRAINT groups_pkey PRIMARY KEY (id);


--
-- Name: password_resets password_resets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY password_resets
    ADD CONSTRAINT password_resets_pkey PRIMARY KEY (id);


--
-- Name: permissions permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY permissions
    ADD CONSTRAINT permissions_pkey PRIMARY KEY (id);


--
-- Name: relay_groups relay_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY relay_groups
    ADD CONSTRAINT relay_groups_pkey PRIMARY KEY (id);


--
-- Name: relays relays_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY relays
    ADD CONSTRAINT relays_pkey PRIMARY KEY (id);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: rules rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY rules
    ADD CONSTRAINT rules_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: site_command_aliases site_command_aliases_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY site_command_aliases
    ADD CONSTRAINT site_command_aliases_pkey PRIMARY KEY (id);


--
-- Name: templates templates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY templates
    ADD CONSTRAINT templates_pkey PRIMARY KEY (id);


--
-- Name: tokens tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY tokens
    ADD CONSTRAINT tokens_pkey PRIMARY KEY (id);


--
-- Name: triggers triggers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY triggers
    ADD CONSTRAINT triggers_pkey PRIMARY KEY (id);


--
-- Name: user_command_aliases user_command_aliases_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY user_command_aliases
    ADD CONSTRAINT user_command_aliases_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: bundle_dynamic_configs_bundle_id_layer_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX bundle_dynamic_configs_bundle_id_layer_name_index ON bundle_dynamic_configs USING btree (bundle_id, layer, name);


--
-- Name: bundle_versions_bundle_id_version_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX bundle_versions_bundle_id_version_index ON bundle_versions USING btree (bundle_id, version);


--
-- Name: bundles_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX bundles_name_index ON bundles USING btree (name);


--
-- Name: chat_handles_provider_id_chat_provider_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX chat_handles_provider_id_chat_provider_user_id_index ON chat_handles USING btree (provider_id, chat_provider_user_id);


--
-- Name: chat_handles_provider_id_handle_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX chat_handles_provider_id_handle_index ON chat_handles USING btree (provider_id, handle);


--
-- Name: chat_handles_user_id_provider_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX chat_handles_user_id_provider_id_index ON chat_handles USING btree (user_id, provider_id);


--
-- Name: chat_providers_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX chat_providers_name_index ON chat_providers USING btree (name);


--
-- Name: command_option_types_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX command_option_types_name_index ON command_option_types USING btree (name);


--
-- Name: command_options_command_id_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX command_options_command_id_name_index ON command_options USING btree (command_version_id, name);


--
-- Name: command_versions_bundle_version_id_command_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX command_versions_bundle_version_id_command_id_index ON command_versions USING btree (bundle_version_id, command_id);


--
-- Name: commands_bundle_id_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX commands_bundle_id_name_index ON commands USING btree (bundle_id, name);


--
-- Name: group_group_membership_member_id_group_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX group_group_membership_member_id_group_id_index ON group_group_membership USING btree (member_id, group_id);


--
-- Name: group_permissions_group_id_permission_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX group_permissions_group_id_permission_id_index ON group_permissions USING btree (group_id, permission_id);


--
-- Name: group_roles_group_id_role_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX group_roles_group_id_role_id_index ON group_roles USING btree (group_id, role_id);


--
-- Name: groups_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX groups_name_index ON groups USING btree (name);


--
-- Name: password_resets_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX password_resets_user_id_index ON password_resets USING btree (user_id);


--
-- Name: permission_bundle_version_permission_id_bundle_version_id_in; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX permission_bundle_version_permission_id_bundle_version_id_in ON permission_bundle_version USING btree (permission_id, bundle_version_id);


--
-- Name: permissions_bundle_id_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX permissions_bundle_id_name_index ON permissions USING btree (bundle_id, name);


--
-- Name: relay_group_assignments_bundle_id_group_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX relay_group_assignments_bundle_id_group_id_index ON relay_group_assignments USING btree (bundle_id, group_id);


--
-- Name: relay_group_memberships_relay_id_group_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX relay_group_memberships_relay_id_group_id_index ON relay_group_memberships USING btree (relay_id, group_id);


--
-- Name: relay_groups_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX relay_groups_name_index ON relay_groups USING btree (name);


--
-- Name: relays_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX relays_name_index ON relays USING btree (name);


--
-- Name: role_permissions_role_id_permission_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX role_permissions_role_id_permission_id_index ON role_permissions USING btree (role_id, permission_id);


--
-- Name: roles_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX roles_name_index ON roles USING btree (name);


--
-- Name: rule_bundle_version_rule_id_bundle_version_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX rule_bundle_version_rule_id_bundle_version_id_index ON rule_bundle_version USING btree (rule_id, bundle_version_id);


--
-- Name: rule_permissions_rule_id_permission_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX rule_permissions_rule_id_permission_id_index ON rule_permissions USING btree (rule_id, permission_id);


--
-- Name: rules_command_id_parse_tree_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX rules_command_id_parse_tree_index ON rules USING btree (command_id, parse_tree);


--
-- Name: site_command_aliases_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX site_command_aliases_name_index ON site_command_aliases USING btree (name);


--
-- Name: templates_bundle_id_adapter_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX templates_bundle_id_adapter_name_index ON templates USING btree (bundle_version_id, adapter, name);


--
-- Name: tokens_user_id_value_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX tokens_user_id_value_index ON tokens USING btree (user_id, value);


--
-- Name: triggers_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX triggers_name_index ON triggers USING btree (name);


--
-- Name: user_command_aliases_name_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX user_command_aliases_name_user_id_index ON user_command_aliases USING btree (name, user_id);


--
-- Name: user_group_membership_member_id_group_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX user_group_membership_member_id_group_id_index ON user_group_membership USING btree (member_id, group_id);


--
-- Name: user_permissions_user_id_permission_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX user_permissions_user_id_permission_id_index ON user_permissions USING btree (user_id, permission_id);


--
-- Name: user_roles_user_id_role_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX user_roles_user_id_role_id_index ON user_roles USING btree (user_id, role_id);


--
-- Name: users_email_address_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_email_address_index ON users USING btree (email_address);


--
-- Name: users_username_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_username_index ON users USING btree (username);


--
-- Name: group_group_membership no_long_range_cycles; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER no_long_range_cycles AFTER INSERT OR UPDATE ON group_group_membership NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE forbid_group_cycles();


--
-- Name: groups protect_admin_group; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER protect_admin_group AFTER DELETE OR UPDATE ON groups NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE protect_admin_group();


--
-- Name: user_group_membership protect_admin_group_membership; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER protect_admin_group_membership AFTER DELETE OR UPDATE ON user_group_membership NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE protect_admin_group_membership();


--
-- Name: roles protect_admin_role; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER protect_admin_role AFTER DELETE OR UPDATE ON roles NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE protect_admin_role();


--
-- Name: role_permissions protect_admin_role_permissions; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER protect_admin_role_permissions AFTER DELETE OR UPDATE ON role_permissions NOT DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE PROCEDURE protect_admin_role_permissions();


--
-- Name: bundle_dynamic_configs bundle_dynamic_configs_bundle_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY bundle_dynamic_configs
    ADD CONSTRAINT bundle_dynamic_configs_bundle_id_fkey FOREIGN KEY (bundle_id) REFERENCES bundles(id) ON DELETE CASCADE;


--
-- Name: bundle_versions bundle_versions_bundle_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY bundle_versions
    ADD CONSTRAINT bundle_versions_bundle_id_fkey FOREIGN KEY (bundle_id) REFERENCES bundles(id) ON DELETE CASCADE;


--
-- Name: chat_handles chat_handles_provider_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY chat_handles
    ADD CONSTRAINT chat_handles_provider_id_fkey FOREIGN KEY (provider_id) REFERENCES chat_providers(id);


--
-- Name: chat_handles chat_handles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY chat_handles
    ADD CONSTRAINT chat_handles_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;


--
-- Name: command_options command_options_command_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY command_options
    ADD CONSTRAINT command_options_command_id_fkey FOREIGN KEY (command_version_id) REFERENCES command_versions(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: command_options command_options_option_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY command_options
    ADD CONSTRAINT command_options_option_type_id_fkey FOREIGN KEY (option_type_id) REFERENCES command_option_types(id) ON DELETE CASCADE;


--
-- Name: command_versions command_versions_bundle_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY command_versions
    ADD CONSTRAINT command_versions_bundle_version_id_fkey FOREIGN KEY (bundle_version_id) REFERENCES bundle_versions(id) ON DELETE CASCADE;


--
-- Name: command_versions command_versions_command_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY command_versions
    ADD CONSTRAINT command_versions_command_id_fkey FOREIGN KEY (command_id) REFERENCES commands(id) ON DELETE CASCADE;


--
-- Name: commands commands_bundle_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY commands
    ADD CONSTRAINT commands_bundle_id_fkey FOREIGN KEY (bundle_id) REFERENCES bundles(id) ON DELETE CASCADE;


--
-- Name: enabled_bundle_versions enabled_bundle_versions_bundle_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY enabled_bundle_versions
    ADD CONSTRAINT enabled_bundle_versions_bundle_id_fkey FOREIGN KEY (bundle_id, version) REFERENCES bundle_versions(bundle_id, version) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: group_group_membership group_group_membership_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY group_group_membership
    ADD CONSTRAINT group_group_membership_group_id_fkey FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE;


--
-- Name: group_group_membership group_group_membership_member_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY group_group_membership
    ADD CONSTRAINT group_group_membership_member_id_fkey FOREIGN KEY (member_id) REFERENCES groups(id) ON DELETE CASCADE;


--
-- Name: group_permissions group_permissions_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY group_permissions
    ADD CONSTRAINT group_permissions_group_id_fkey FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE;


--
-- Name: group_permissions group_permissions_permission_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY group_permissions
    ADD CONSTRAINT group_permissions_permission_id_fkey FOREIGN KEY (permission_id) REFERENCES permissions(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: group_roles group_roles_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY group_roles
    ADD CONSTRAINT group_roles_group_id_fkey FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE;


--
-- Name: group_roles group_roles_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY group_roles
    ADD CONSTRAINT group_roles_role_id_fkey FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE;


--
-- Name: password_resets password_resets_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY password_resets
    ADD CONSTRAINT password_resets_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;


--
-- Name: permission_bundle_version permission_bundle_version_bundle_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY permission_bundle_version
    ADD CONSTRAINT permission_bundle_version_bundle_version_id_fkey FOREIGN KEY (bundle_version_id) REFERENCES bundle_versions(id) ON DELETE CASCADE;


--
-- Name: permission_bundle_version permission_bundle_version_permission_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY permission_bundle_version
    ADD CONSTRAINT permission_bundle_version_permission_id_fkey FOREIGN KEY (permission_id) REFERENCES permissions(id) ON DELETE CASCADE;


--
-- Name: permissions permissions_bundle_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY permissions
    ADD CONSTRAINT permissions_bundle_id_fkey FOREIGN KEY (bundle_id) REFERENCES bundles(id) ON DELETE CASCADE;


--
-- Name: relay_group_assignments relay_group_assignments_bundle_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY relay_group_assignments
    ADD CONSTRAINT relay_group_assignments_bundle_id_fkey FOREIGN KEY (bundle_id) REFERENCES bundles(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: relay_group_assignments relay_group_assignments_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY relay_group_assignments
    ADD CONSTRAINT relay_group_assignments_group_id_fkey FOREIGN KEY (group_id) REFERENCES relay_groups(id) ON DELETE CASCADE;


--
-- Name: relay_group_memberships relay_group_memberships_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY relay_group_memberships
    ADD CONSTRAINT relay_group_memberships_group_id_fkey FOREIGN KEY (group_id) REFERENCES relay_groups(id) ON DELETE CASCADE;


--
-- Name: relay_group_memberships relay_group_memberships_relay_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY relay_group_memberships
    ADD CONSTRAINT relay_group_memberships_relay_id_fkey FOREIGN KEY (relay_id) REFERENCES relays(id) ON DELETE CASCADE;


--
-- Name: role_permissions role_permissions_permission_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY role_permissions
    ADD CONSTRAINT role_permissions_permission_id_fkey FOREIGN KEY (permission_id) REFERENCES permissions(id) ON DELETE CASCADE;


--
-- Name: role_permissions role_permissions_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY role_permissions
    ADD CONSTRAINT role_permissions_role_id_fkey FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE;


--
-- Name: rule_bundle_version rule_bundle_version_bundle_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY rule_bundle_version
    ADD CONSTRAINT rule_bundle_version_bundle_version_id_fkey FOREIGN KEY (bundle_version_id) REFERENCES bundle_versions(id) ON DELETE CASCADE;


--
-- Name: rule_bundle_version rule_bundle_version_rule_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY rule_bundle_version
    ADD CONSTRAINT rule_bundle_version_rule_id_fkey FOREIGN KEY (rule_id) REFERENCES rules(id) ON DELETE CASCADE;


--
-- Name: rule_permissions rule_permissions_permission_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY rule_permissions
    ADD CONSTRAINT rule_permissions_permission_id_fkey FOREIGN KEY (permission_id) REFERENCES permissions(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: rule_permissions rule_permissions_rule_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY rule_permissions
    ADD CONSTRAINT rule_permissions_rule_id_fkey FOREIGN KEY (rule_id) REFERENCES rules(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: rules rules_command_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY rules
    ADD CONSTRAINT rules_command_id_fkey FOREIGN KEY (command_id) REFERENCES commands(id) ON DELETE CASCADE;


--
-- Name: templates templates_bundle_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY templates
    ADD CONSTRAINT templates_bundle_id_fkey FOREIGN KEY (bundle_version_id) REFERENCES bundle_versions(id) ON DELETE CASCADE;


--
-- Name: tokens tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY tokens
    ADD CONSTRAINT tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;


--
-- Name: triggers triggers_as_user_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY triggers
    ADD CONSTRAINT triggers_as_user_fkey FOREIGN KEY (as_user) REFERENCES users(username) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: user_command_aliases user_command_aliases_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY user_command_aliases
    ADD CONSTRAINT user_command_aliases_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id);


--
-- Name: user_group_membership user_group_membership_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY user_group_membership
    ADD CONSTRAINT user_group_membership_group_id_fkey FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE;


--
-- Name: user_group_membership user_group_membership_member_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY user_group_membership
    ADD CONSTRAINT user_group_membership_member_id_fkey FOREIGN KEY (member_id) REFERENCES users(id) ON DELETE CASCADE;


--
-- Name: user_permissions user_permissions_permission_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY user_permissions
    ADD CONSTRAINT user_permissions_permission_id_fkey FOREIGN KEY (permission_id) REFERENCES permissions(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: user_permissions user_permissions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY user_permissions
    ADD CONSTRAINT user_permissions_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;


--
-- Name: user_roles user_roles_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY user_roles
    ADD CONSTRAINT user_roles_role_id_fkey FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE;


--
-- Name: user_roles user_roles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY user_roles
    ADD CONSTRAINT user_roles_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

INSERT INTO "schema_migrations" (version) VALUES (20150923192906), (20150924181513), (20150924194327), (20150926010327), (20150926011942), (20150928145253), (20150928155606), (20150929153342), (20150929172700), (20150929173757), (20150929174803), (20150930171857), (20151001144249), (20151001150901), (20151001170322), (20151001172009), (20151001173130), (20151002154545), (20151006181054), (20151014162726), (20151014192020), (20151015163606), (20151019181519), (20151028025449), (20151103003341), (20151106195033), (20151106202916), (20151109191832), (20151117110748), (20151118002150), (20151119151854), (20151229190256), (20160105230435), (20160113160251), (20160113210711), (20160118181050), (20160122152844), (20160205213426), (20160209185334), (20160210165002), (20160211192002), (20160216200959), (20160219160541), (20160219161248), (20160223163039), (20160224180326), (20160224184802), (20160301224759), (20160309201354), (20160317183129), (20160322222933), (20160325211544), (20160328115654), (20160328121935), (20160329185210), (20160331174731), (20160401211833), (20160401212441), (20160404135526), (20160404191532), (20160406172300), (20160411203730), (20160415152542), (20160418174310), (20160419154716), (20160502183545), (20160505200538), (20160506203250), (20160509155102), (20160509171951), (20160517130803), (20160523152120), (20160524190528), (20160531183124), (20160606205428), (20160608203636), (20160615225508), (20160617190613), (20160623204553), (20160628193728), (20160628204409), (20160705194714), (20160725170913), (20160803163007), (20160803165909), (20160803181844), (20160805202712), (20160808151518), (20160808153502), (20160808154520), (20160830190854), (20160830191049), (20160830192755), (20160909200244), (20160916144939), (20160926135327), (20161202162538), (20161220162331), (20170106205545);

